import sys.FileSystem;
import sys.io.File;
import haxe.io.Path;
import haxe.macro.Compiler;
import haxe.macro.Type;
import haxe.macro.Type.BaseType;
import haxe.macro.Type.AbstractType;
import haxe.macro.Context;

class AS3ExternsGenerator {
	private static final ALWAYS_ALLOWED_REFERENCE_TYPES = [
		"Any",
		"Array",
		"Bool",
		"Class",
		"Date",
		"Dynamic",
		"Float",
		"Int",
		"String",
		"UInt",
		"Void"
	];
	private static final NON_NULLABLE_AS3_TYPES = ["Boolean", "Number", "int", "uint"];
	// AS3 in Royale allows most keywords as symbol names, unlike older SDKs
	// however, these are still not allowed
	private static final DISALLOWED_AS3_NAMES = ["goto", "public", "private", "protected", "internal"];
	private static final eregAccessor = ~/^(g|s)et_[\w]+$/;
	private static final QNAMES_TO_REWRITE:Map<String, String> = [
		"Any" => "*",
		"Bool" => "Boolean",
		"Dynamic" => "*",
		"Float" => "Number",
		"Int" => "int",
		"UInt" => "uint",
		"Void" => "void"
	];

	public static function generate(?options:AS3GeneratorOptions):Void {
		var outputDirPath = Path.join([Path.directory(Compiler.getOutput()), "as3-externs"]);
		if (options != null && options.outputPath != null) {
			outputDirPath = options.outputPath;
		}
		if (!Path.isAbsolute(outputDirPath)) {
			outputDirPath = Path.join([Sys.getCwd(), outputDirPath]);
		}
		Context.onGenerate(types -> {
			var generator = new AS3ExternsGenerator(options);
			generator.generateForTypes(types, outputDirPath);
		});
	}

	private var options:AS3GeneratorOptions;

	private function new(?options:AS3GeneratorOptions) {
		this.options = options;
	}

	public function generateForTypes(types:Array<Type>, outputDirPath:String):Void {
		for (type in types) {
			switch (type) {
				case TInst(t, params):
					var classType = t.get();
					if (shouldSkipBaseType(classType, false)) {
						continue;
					}
					if (classType.isInterface) {
						var generated = generateInterface(classType, params);
						writeGenerated(outputDirPath, classType, generated);
					} else {
						var generated = generateClass(classType, params);
						writeGenerated(outputDirPath, classType, generated);
					}
				case TEnum(t, params):
					var enumType = t.get();
					if (shouldSkipBaseType(enumType, false)) {
						continue;
					}
					var generated = generateEnum(enumType, params);
					writeGenerated(outputDirPath, enumType, generated);
				case TAbstract(t, params):
					var abstractType = t.get();
					if (shouldSkipBaseType(abstractType, false)) {
						continue;
					}
					if (!abstractType.meta.has(":enum")) {
						// ignore non-enum abstracts because they don't exist in openfl-js
						continue;
					}
					var generated = generateAbstractEnum(abstractType, params);
					writeGenerated(outputDirPath, abstractType, generated);
				case TType(t, params):
					// ignore typedefs because they don't exist in openfl-js
				default:
					trace("Unexpected type: " + type);
			}
		}
	}

	private function isInPackage(expected:Array<String>, actual:Array<String>, exact:Bool):Bool {
		if (expected == null) {
			return true;
		}
		if (exact) {
			if (actual.length != expected.length) {
				return false;
			}
		} else if (actual.length < expected.length) {
			return false;
		}
		for (i in 0...expected.length) {
			var actualPart = actual[i];
			var expectedPart = expected[i];
			if (actualPart != expectedPart) {
				return false;
			}
		}
		return true;
	}

	private function isInHiddenPackage(pack:Array<String>):Bool {
		for (part in pack) {
			if (part.charAt(0) == "_") {
				return true;
			}
		}
		return false;
	}

	private function shouldSkipMacroType(type:Type, asReference:Bool):Bool {
		var baseType:BaseType = null;
		while (type != null) {
			switch (type) {
				case TInst(t, params):
					var classType = t.get();
					switch (classType.kind) {
						case KTypeParameter(constraints):
							var typeParamSourceQname = classType.pack.join(".");
							if (QNAMES_TO_REWRITE.exists(typeParamSourceQname)) {
								typeParamSourceQname = QNAMES_TO_REWRITE.get(typeParamSourceQname);
							}
							if (typeParamSourceQname == "Vector")
							{
								// don't let Vector.<T> become Vector.<*>
								return false;
							}
						default:
					}
					baseType = classType;
					break;
				case TEnum(t, params):
					baseType = t.get();
					break;
				case TAbstract(t, params):
					var abstractType = t.get();
					if (abstractType.name == "Null" && abstractType.pack.length == 0) {
						return shouldSkipMacroType(params[0], asReference);
					}
					type = abstractType.type;
					switch (type) {
						case TAbstract(t, underlyingParams):
							var result = baseTypeToQname(abstractType, params);
							var compareTo = baseTypeToQname(t.get(), underlyingParams);
							if (result == compareTo) {
								// this avoids an infinite loop
								baseType = abstractType;
								break;
							}
						default:
					}
				case TType(t, params):
					type = t.get().type;
				case TDynamic(t):
					return false;
				case TAnonymous(a):
					return false;
				case TFun(args, ret):
					return false;
				case TLazy(f):
					type = f();
				case TMono(t):
					type = t.get();
				default:
					break;
			}
		}
		if (baseType == null) {
			return true;
		}
		return shouldSkipBaseType(baseType, asReference);
	}

	private function shouldSkipBaseType(baseType:BaseType, asReference:Bool):Bool {
		if (asReference && baseType.pack.length == 0 && ALWAYS_ALLOWED_REFERENCE_TYPES.indexOf(baseType.name) != -1) {
			return false;
		}
		if (baseType.isPrivate || (baseType.isExtern && !asReference) || isInHiddenPackage(baseType.pack)) {
			return true;
		}
		final qname = baseTypeToQname(baseType, [], false);
		if ((options == null || options.renameSymbols == null || options.renameSymbols.indexOf(qname) == -1)
				&& baseType.meta.has(":noCompletion")) {
			return true;
		}
		if (options != null) {
			if (options.includedPackages != null) {
				for (includedPackage in options.includedPackages) {
					if (isInPackage(includedPackage.split("."), baseType.pack, false)) {
						if (options.excludeSymbols != null) {
							var qname = baseTypeToQname(baseType, []);
							if (options.excludeSymbols.indexOf(qname) != -1) {
								return true;
							}
						}
						return false;
					}
				}
				if (!asReference) {
					return true;
				}
			} else if (options.excludeSymbols != null) {
				var qname = baseTypeToQname(baseType, []);
				if (options.excludeSymbols.indexOf(qname) != -1) {
					return true;
				}
			}
			if (asReference) {
				if (options.allowedPackageReferences != null) {
					for (allowedPackage in options.allowedPackageReferences) {
						if (isInPackage(allowedPackage.split("."), baseType.pack, false)) {
							return false;
						}
					}
					return true;
				}
			}
		}
		return false;
	}

	private function generateClass(classType:ClassType, params:Array<Type>):String {
		var result = new StringBuf();
		result.add('package');
		var qname = baseTypeToQname(classType, params, false);
		var qnameParts = qname.split(".");
		qnameParts.pop();
		var packageName:String = null;
		if (qnameParts.length > 0) {
			packageName = qnameParts.join(".");
			result.add(' $packageName');
		}
		result.add(' {\n');
		result.add(generateClassTypeImports(classType));
		result.add(generateDocs(classType.doc, true, ""));
		var className = baseTypeToUnqualifiedName(classType, params, false);
		result.add('public class $className');
		var includeFieldsFrom:ClassType = null;
		if (classType.superClass != null) {
			var superClassType = classType.superClass.t.get();
			if (shouldSkipBaseType(superClassType, true)) {
				includeFieldsFrom = superClassType;
			} else {
				result.add(' extends ${baseTypeToQname(superClassType, classType.superClass.params)}');
			}
		}
		var interfaces = classType.interfaces;
		var foundFirstInterface = false;
		for (i in 0...interfaces.length) {
			var interfaceRef = interfaces[i];
			var implementedInterfaceType = interfaceRef.t.get();
			if (!shouldSkipBaseType(implementedInterfaceType, true)) {
				if (foundFirstInterface) {
					result.add(', ');
				} else {
					foundFirstInterface = true;
					result.add(' implements ');
				}
				result.add(baseTypeToQname(implementedInterfaceType, interfaceRef.params));
			}
		}
		result.add(' {\n');
		if (classType.constructor != null) {
			var constructor = classType.constructor.get();
			if (!shouldSkipField(constructor, classType)) {
				result.add(generateClassField(constructor, classType, false, null));
			}
		}
		while (includeFieldsFrom != null) {
			for (classField in includeFieldsFrom.fields.get()) {
				if (shouldSkipField(classField, includeFieldsFrom)) {
					continue;
				}
				if (Lambda.exists(classType.fields.get(), item -> item.name == classField.name)) {
					continue;
				}
				result.add(generateClassField(classField, includeFieldsFrom, false, interfaces));
			}
			if (includeFieldsFrom.superClass == null) {
				break;
			}
			includeFieldsFrom = includeFieldsFrom.superClass.t.get();
		}
		for (classField in classType.statics.get()) {
			if (shouldSkipField(classField, classType)) {
				continue;
			}
			result.add(generateClassField(classField, classType, true, null));
		}
		for (classField in classType.fields.get()) {
			if (shouldSkipField(classField, classType)) {
				continue;
			}
			result.add(generateClassField(classField, classType, false, interfaces));
		}
		result.add('}\n');
		result.add('}\n');
		return result.toString();
	}

	private function generateQnameParams(params:Array<Type>):String {
		if (params.length == 0) {
			return "";
		}
		var result = new StringBuf();
		result.add('.<');
		for (i in 0...params.length) {
			var param = params[i];
			if (i > 0) {
				result.add(', ');
			}
			if (shouldSkipMacroType(param, true)) {
				result.add("*");
			} else {
				result.add(macroTypeToQname(param));
			}
		}
		result.add('>');
		return result.toString();
	}

	private function generateClassField(classField:ClassField, classType:ClassType, isStatic:Bool,
			interfaces:Array<{t:Ref<ClassType>, params:Array<Type>}>):String {
		var result = new StringBuf();
		result.add(generateDocs(classField.doc, false, "\t"));
		result.add("\t");
		var superClassType:ClassType = null;
		var skippedSuperClass = false;
		if (classType != null && classType.superClass != null) {
			superClassType = classType.superClass.t.get();
			skippedSuperClass = shouldSkipBaseType(superClassType, true);
		}
		switch (classField.kind) {
			case FMethod(k):
				if (!skippedSuperClass) {
					if (classType != null) {
						for (current in classType.overrides) {
							if (current.get().name == classField.name) {
								result.add('override ');
							}
						}
					}
				}
				if (classField.isPublic) {
					result.add('public ');
				}
				if (isStatic) {
					result.add('static ');
				}
				result.add('function ');
				if (classField.name == "new" && classType != null) {
					var className = baseTypeToUnqualifiedName(classType, [], false);
					result.add(className);
				} else {
					result.add(classField.name);
				}
				switch (classField.type) {
					case TFun(args, ret):
						var argsAndRet = {args: args, ret: ret};
						findInterfaceArgsAndRet(classField, classType, argsAndRet);
						args = argsAndRet.args;
						ret = argsAndRet.ret;
						result.add('(');
						var hadOpt = false;
						for (i in 0...args.length) {
							var arg = args[i];
							if (i > 0) {
								result.add(', ');
							}
							result.add(arg.name);
							result.add(':');
							if (shouldSkipMacroType(arg.t, true)) {
								result.add('*');
							} else {
								result.add(macroTypeToQname(arg.t));
							}
							if (arg.opt || hadOpt) {
								hadOpt = true;
								result.add(' = undefined');
							}
						}
						result.add(')');
						if (classField.name != "new") {
							result.add(':');
							var retQname = if (shouldSkipMacroType(ret, true)) {
								'*';
							} else {
								macroTypeToQname(ret);
							}
							result.add(retQname);
							switch (retQname) {
								case "void":
									result.add(' {}');
								case "Number" | "int" | "uint":
									result.add(" { return 0; }");
								case "Boolean":
									result.add(" { return false; }");
								default:
									result.add(" { return null; }");
							}
						} else {
							if (superClassType != null && !skippedSuperClass) {
								result.add(' {\n');
								result.add('\t\tsuper(');
								if (superClassType.constructor != null) {
									switch (superClassType.constructor.get().type) {
										case TFun(args, ret):
											for (i in 0...args.length) {
												if (i > 0) {
													result.add(', ');
												}
												result.add('undefined');
											}
										default:
									}
								}
								result.add(');\n');
								result.add('\t}');
							} else {
								result.add(' {}');
							}
						}
					default:
				}
			case FVar(read, write):
				var isAccessor = read == AccCall || write == AccCall || mustBeAccessor(classField.name, interfaces);
				var argsAndRet = {args: [], ret: classField.type};
				findInterfaceArgsAndRet(classField, classType, argsAndRet);
				var ret = argsAndRet.ret;
				if (isAccessor) {
					var hasGetter = read == AccCall || read == AccNormal;
					var hasSetter = write == AccCall || write == AccNormal;
					if (hasGetter) {
						if (classField.isPublic) {
							result.add('public ');
						}
						if (isStatic) {
							result.add('static ');
						}
						result.add('function get ');
						result.add(classField.name);
						result.add('():');
						var retQname = if (shouldSkipMacroType(ret, true)) {
							'*';
						} else {
							macroTypeToQname(ret);
						}
						result.add(retQname);
						switch (retQname) {
							case "void":
								result.add(' {}');
							case "Number" | "int" | "uint":
								result.add(" { return 0; }");
							case "Boolean":
								result.add(" { return false; }");
							default:
								result.add(" { return null; }");
						}
					}
					if (hasSetter) {
						if (hasGetter) {
							result.add('\n\t');
						}
						if (classField.isPublic) {
							result.add('public ');
						}
						if (isStatic) {
							result.add('static ');
						}
						result.add('function set ');
						result.add(classField.name);
						result.add('(value:');
						if (shouldSkipMacroType(ret, true)) {
							result.add('*');
						} else {
							result.add(macroTypeToQname(ret));
						}
						result.add('):void {}');
					}
				} else {
					if (classField.isPublic) {
						result.add('public ');
					}
					if (isStatic) {
						result.add('static ');
					}
					if (classField.isFinal || read == AccInline || write == AccInline) {
						result.add('const ');
					} else {
						result.add('var ');
					}
					result.add(classField.name);
					result.add(':');
					if (shouldSkipMacroType(ret, true)) {
						result.add('*');
					} else {
						result.add(macroTypeToQname(ret));
					}
					if (classField.isFinal || read == AccInline || write == AccInline) {
						var expr = classField.expr().expr;
						while (true) {
							switch (expr) {
								case TCast(e, m):
									expr = e.expr;
								case TConst(TBool(b)):
									result.add(' = $b');
									break;
								case TConst(TFloat(f)):
									result.add(' = $f');
									break;
								case TConst(TInt(i)):
									result.add(' = $i');
									break;
								case TConst(TString(s)):
									result.add(' = "$s"');
									break;
								case TConst(TNull):
									result.add(' = null');
								default:
									break;
							}
						}
					}
					result.add(";");
				}
		}
		result.add('\n');
		return result.toString();
	}

	private function mustBeAccessor(fieldName:String, interfaces:Array<{t:Ref<ClassType>, params:Array<Type>}>):Bool {
		if (interfaces == null) {
			return false;
		}
		for (interfaceRef in interfaces) {
			var implementedInterface = interfaceRef.t.get();
			for (classField in implementedInterface.fields.get()) {
				if (classField.name == fieldName) {
					switch (classField.kind) {
						case FVar(read, write):
							return true;
						default:
							return false;
					}
				}
			}
			if (mustBeAccessor(fieldName, implementedInterface.interfaces)) {
				return true;
			}
		}
		return false;
	}

	private function generateClassTypeImports(classType:ClassType):String {
		var qnames:Map<String, Bool> = [];
		if (classType.constructor != null) {
			var constructor = classType.constructor.get();
			if (!shouldSkipField(constructor, classType)) {
				switch (constructor.type) {
					case TFun(args, ret):
						for (arg in args) {
							var argType = arg.t;
							if (!canSkipMacroTypeImport(argType, classType.pack) && !shouldSkipMacroType(argType, true)) {
								var qname = macroTypeToQname(argType, false);
								qnames.set(qname, true);
							}
						}
					default:
				}
			}
		}
		if (classType.superClass != null) {
			var superClass = classType.superClass.t.get();
			if (!shouldSkipBaseType(superClass, true) && !canSkipBaseTypeImport(superClass, classType.pack)) {
				var qname = baseTypeToQname(superClass, [], false);
				qnames.set(qname, true);
			}
		}
		for (interfaceRef in classType.interfaces) {
			var interfaceType = interfaceRef.t.get();
			if (!shouldSkipBaseType(interfaceType, true) && !canSkipBaseTypeImport(interfaceType, classType.pack)) {
				var qname = baseTypeToQname(interfaceType, [], false);
				qnames.set(qname, true);
			}
		}
		for (classField in classType.statics.get()) {
			if (shouldSkipField(classField, classType)) {
				continue;
			}
			switch (classField.type) {
				case TFun(args, ret):
					for (arg in args) {
						var argType = arg.t;
						if (!canSkipMacroTypeImport(argType, classType.pack) && !shouldSkipMacroType(argType, true)) {
							var qname = macroTypeToQname(argType, false);
							qnames.set(qname, true);
						}
					}
					if (!canSkipMacroTypeImport(ret, classType.pack) && !shouldSkipMacroType(ret, true)) {
						var qname = macroTypeToQname(ret, false);
						qnames.set(qname, true);
					}
				default:
					if (!canSkipMacroTypeImport(classField.type, classType.pack) && !shouldSkipMacroType(classField.type, true)) {
						var qname = macroTypeToQname(classField.type, false);
						qnames.set(qname, true);
					}
			}
		}
		for (classField in classType.fields.get()) {
			if (shouldSkipField(classField, classType)) {
				continue;
			}
			switch (classField.type) {
				case TFun(args, ret):
					for (arg in args) {
						var argType = arg.t;
						if (!canSkipMacroTypeImport(argType, classType.pack) && !shouldSkipMacroType(argType, true)) {
							var qname = macroTypeToQname(argType, false);
							qnames.set(qname, true);
						}
					}
					if (!canSkipMacroTypeImport(ret, classType.pack) && !shouldSkipMacroType(ret, true)) {
						var qname = macroTypeToQname(ret, false);
						qnames.set(qname, true);
					}
				default:
					if (!canSkipMacroTypeImport(classField.type, classType.pack) && !shouldSkipMacroType(classField.type, true)) {
						var qname = macroTypeToQname(classField.type, false);
						qnames.set(qname, true);
					}
			}
		}

		var result = new StringBuf();
		for (qname in qnames.keys()) {
			result.add('import $qname;\n');
		}
		return result.toString();
	}

	private function generateInterface(interfaceType:ClassType, params:Array<Type>):String {
		var result = new StringBuf();
		result.add('package');
		var qname = baseTypeToQname(interfaceType, params, false);
		var qnameParts = qname.split(".");
		qnameParts.pop();
		if (qnameParts.length > 0) {
			result.add(' ${qnameParts.join(".")}');
		}
		result.add(' {\n');
		result.add(generateClassTypeImports(interfaceType));
		result.add(generateDocs(interfaceType.doc, true, ""));
		var interfaceName = baseTypeToUnqualifiedName(interfaceType, params, false);
		result.add('public interface ${interfaceName}');
		var interfaces = interfaceType.interfaces;
		var firstInterface = false;
		for (i in 0...interfaces.length) {
			var interfaceRef = interfaces[i];
			var implementedInterfaceType = interfaceRef.t.get();
			if (!shouldSkipBaseType(implementedInterfaceType, true)) {
				if (firstInterface) {
					result.add(', ');
				} else {
					firstInterface = true;
					result.add(' extends ');
				}
				result.add(baseTypeToQname(implementedInterfaceType, interfaceRef.params));
			}
		}
		result.add(' {\n');
		for (interfaceField in interfaceType.fields.get()) {
			if (shouldSkipField(interfaceField, interfaceType)) {
				continue;
			}
			result.add(generateInterfaceField(interfaceField));
		}
		result.add('}\n');
		result.add('}\n');
		return result.toString();
	}

	private function generateInterfaceField(interfaceField:ClassField):String {
		var result = new StringBuf();
		result.add(generateDocs(interfaceField.doc, false, "\t"));
		result.add("\t");
		switch (interfaceField.kind) {
			case FMethod(k):
				result.add('function ');
				result.add(interfaceField.name);
				switch (interfaceField.type) {
					case TFun(args, ret):
						result.add('(');
						var hadOpt = false;
						for (i in 0...args.length) {
							var arg = args[i];
							if (i > 0) {
								result.add(', ');
							}
							result.add(arg.name);
							result.add(':');
							if (shouldSkipMacroType(arg.t, true)) {
								result.add('*');
							} else {
								result.add(macroTypeToQname(arg.t));
							}
							if (arg.opt || hadOpt) {
								hadOpt = true;
								result.add(' = undefined');
							}
						}
						result.add('):');
						if (shouldSkipMacroType(ret, true)) {
							result.add('*');
						} else {
							result.add(macroTypeToQname(ret));
						}
					default:
				}
			case FVar(read, write):
				// skip AccNormal fields because AS3 supports get/set only
				var hasGetter = read == AccCall;
				var hasSetter = write == AccCall;
				if (hasGetter) {
					result.add('function get ');
					result.add(interfaceField.name);
					result.add('():');
					if (shouldSkipMacroType(interfaceField.type, true)) {
						result.add('*');
					} else {
						result.add(macroTypeToQname(interfaceField.type));
					}
				}
				if (hasSetter) {
					if (hasGetter) {
						result.add(';\n\t');
					}
					result.add('function set ');
					result.add(interfaceField.name);
					result.add('(value:');
					if (shouldSkipMacroType(interfaceField.type, true)) {
						result.add('*');
					} else {
						result.add(macroTypeToQname(interfaceField.type));
					}
					result.add('):void');
				}
		}
		result.add(';\n');
		return result.toString();
	}

	private function generateEnum(enumType:EnumType, params:Array<Type>):String {
		var result = new StringBuf();
		result.add('package');
		var qname = baseTypeToQname(enumType, params, false);
		var qnameParts = qname.split(".");
		qnameParts.pop();
		if (qnameParts.length > 0) {
			result.add(' ${qnameParts.join(".")}');
		}
		result.add(' {\n');
		result.add(generateDocs(enumType.doc, true, ""));
		var enumName = baseTypeToUnqualifiedName(enumType, params, false);
		result.add('public class ${enumName}');
		result.add(' {\n');
		for (enumField in enumType.constructs) {
			result.add(generateEnumField(enumField, enumType, params));
		}
		result.add('}\n');
		result.add('}\n');
		return result.toString();
	}

	private function generateEnumField(enumField:EnumField, enumType:EnumType, enumTypeParams:Array<Type>):String {
		var result = new StringBuf();
		result.add(generateDocs(enumField.doc, false, "\t"));
		result.add("\t");
		result.add('public static ');
		result.add('const ');
		result.add(enumField.name);
		result.add(':');
		result.add(baseTypeToQname(enumType, enumTypeParams));
		result.add(';');
		result.add('\n');
		return result.toString();
	}

	private function generateAbstractEnum(abstractType:AbstractType, params:Array<Type>):String {
		var result = new StringBuf();
		result.add('package');
		var qname = baseTypeToQname(abstractType, params, false);
		var qnameParts = qname.split(".");
		qnameParts.pop();
		if (qnameParts.length > 0) {
			result.add(' ${qnameParts.join(".")}');
		}
		result.add(' {\n');
		result.add(generateDocs(abstractType.doc, true, ""));
		var abstractName = baseTypeToUnqualifiedName(abstractType, params, false);
		result.add('public class ${abstractName}');
		result.add(' {\n');
		if (abstractType.impl != null) {
			var classType = abstractType.impl.get();
			for (classField in classType.statics.get()) {
				if (shouldSkipField(classField, classType)) {
					continue;
				}
				result.add(generateClassField(classField, null, true, []));
			}
		}
		result.add('}\n');
		result.add('}\n');
		return result.toString();
	}

	private function generateDocs(doc:String, externs:Bool, indent:String):String {
		if (doc == null || StringTools.trim(doc).length == 0) {
			if (externs) {
				return '$indent/**\n$indent * @externs\n$indent */\n';
			}
			return "";
		}
		
		var result = new StringBuf();
		result.add('$indent/**\n');
		var lines = ~/\r?\n/g.split(doc);
		var addedLine = false;
		var checkedLeadingStar = false;
		var hasLeadingStar = false;
		for (line in lines) {
			if (!addedLine && ~/^\s*$/.match(line)) {
				continue;
			}
			addedLine = true;
			var leadingStar = ~/^(\s*\*\s*)/;
			if ((!checkedLeadingStar || hasLeadingStar) && leadingStar.match(line)) {
				checkedLeadingStar = true;
				hasLeadingStar = true;
				line = line.substr(leadingStar.matchedPos().len);
			} else if (!checkedLeadingStar) {
				checkedLeadingStar = true;
				hasLeadingStar = false;
			}
			result.add('$indent * $line\n');
		}
		if (externs) {
			result.add('$indent * @externs\n');
		}
		result.add('$indent */\n');
		return result.toString();
	}

	private function shouldSkipField(classField:ClassField, classType:ClassType):Bool {
		if (classField.name != "new") {
			if (!classField.isPublic
				|| classField.isExtern
				|| classField.meta.has(":noCompletion")
				|| DISALLOWED_AS3_NAMES.indexOf(classField.name) != -1) {
				return true;
			}
		}

		if (classType != null && classType.isInterface) {
			if (classField.kind.equals(FieldKind.FMethod(MethNormal)) && eregAccessor.match(classField.name)) {
				return true;
			}
		}
		return false;
	}

	private function canSkipMacroTypeImport(type:Type, currentPackage:Array<String>):Bool {
		var baseType:BaseType = null;
		while (type != null) {
			switch (type) {
				case TInst(t, params):
					var classType = t.get();
					switch (classType.kind) {
						case KTypeParameter(constraints):
							return true;
						default:
					}
					baseType = classType;
					break;
				case TEnum(t, params):
					baseType = t.get();
					break;
				case TAbstract(t, params):
					var abstractType = t.get();
					return canSkipAbstractTypeImport(abstractType, params, currentPackage);
				case TType(t, params):
					var typedefType = t.get();
					type = typedefType.type;
				case TDynamic(t):
					break;
				case TAnonymous(a):
					break;
				case TFun(args, ret):
					break;
				case TLazy(f):
					type = f();
				case TMono(t):
					type = t.get();
				default:
					break;
			}
		}
		if (baseType == null) {
			return true;
		}
		return canSkipBaseTypeImport(baseType, currentPackage);
	}

	private function canSkipAbstractTypeImport(abstractType:AbstractType, params:Array<Type>, currentPackage:Array<String>):Bool {
		var pack = abstractType.pack;
		if (abstractType.name == "Null" && pack.length == 0) {
			return canSkipMacroTypeImport(params[0], currentPackage);
		}
		var underlyingType = abstractType.type;
		switch (underlyingType) {
			case TAbstract(t, underlyingParams):
				var result = baseTypeToQname(abstractType, params, false);
				var compareTo = baseTypeToQname(t.get(), underlyingParams, false);
				if (result == compareTo) {
					// this avoids an infinite loop
					return canSkipBaseTypeImport(abstractType, currentPackage);
				}
			default:
		}
		return canSkipMacroTypeImport(underlyingType, currentPackage);
	}

	private function canSkipBaseTypeImport(baseType:BaseType, currentPackage:Array<String>):Bool {
		if (baseType == null) {
			return true;
		}
		var qname = baseTypeToQname(baseType, []);
		if (qname.indexOf(".") == -1) {
			return true;
		}
		if (isInPackage(currentPackage, baseType.pack, true)) {
			return true;
		}
		return false;
	}

	private function macroTypeToQname(type:Type, includeParams:Bool = true):String {
		while (type != null) {
			switch (type) {
				case TInst(t, params):
					var classType = t.get();
					switch (classType.kind) {
						case KTypeParameter(constraints):
							var typeParamSourceQname = classType.pack.join(".");
							if (QNAMES_TO_REWRITE.exists(typeParamSourceQname)) {
								typeParamSourceQname = QNAMES_TO_REWRITE.get(typeParamSourceQname);
							}
							if (typeParamSourceQname == "Vector")
							{
								return baseTypeToQname(classType, params, includeParams);
							}
							return "*";
						default:
					}
					return baseTypeToQname(classType, params, includeParams);
				case TEnum(t, params):
					return baseTypeToQname(t.get(), params, includeParams);
				case TAbstract(t, params):
					return abstractTypeToQname(t.get(), params, includeParams);
				case TType(t, params):
					var defType = t.get();
					if (options != null && options.renameSymbols != null) {
						var buffer = new StringBuf();
						if (defType.pack.length > 0) {
							buffer.add(defType.pack.join("."));
							buffer.add(".");
						}
						buffer.add(defType.name);
						var qname = buffer.toString();
						var renameSymbols = options.renameSymbols;
						var i = 0;
						while (i < renameSymbols.length) {
							var originalName = renameSymbols[i];
							i++;
							var newName = renameSymbols[i];
							i++;
							if (originalName == qname) {
								qname = newName;
								return qname;
							}
						}
					}
					type = t.get().type;
				case TDynamic(t):
					return "*";
				case TAnonymous(a):
					return "Object";
				case TFun(args, ret):
					return "Function";
				case TLazy(f):
					type = f();
				case TMono(t):
					type = t.get();
				default:
					return "*";
			}
		}
		return "*";
	}

	private function baseTypeToQname(baseType:BaseType, params:Array<Type>, includeParams:Bool = true):String {
		if (baseType == null) {
			return "*";
		}
		var buffer = new StringBuf();
		if (baseType.pack.length > 0) {
			buffer.add(baseType.pack.join("."));
			buffer.add(".");
		}
		buffer.add(baseType.name);
		var qname = buffer.toString();
		if (options != null && options.renameSymbols != null) {
			var renameSymbols = options.renameSymbols;
			var i = 0;
			while (i < renameSymbols.length) {
				var originalName = renameSymbols[i];
				i++;
				var newName = renameSymbols[i];
				i++;
				if (originalName == qname) {
					qname = newName;
					break;
				}
			}
		}

		if (QNAMES_TO_REWRITE.exists(qname)) {
			qname = QNAMES_TO_REWRITE.get(qname);
		}

		if (!includeParams || params.length == 0 || qname != "Vector") {
			return qname;
		}

		buffer = new StringBuf();
		buffer.add(qname);
		buffer.add(generateQnameParams(params));
		return buffer.toString();
	}

	private function baseTypeToUnqualifiedName(baseType:BaseType, params:Array<Type>, includeParams:Bool = true):String {
		if (baseType == null) {
			return "*";
		}
		var qname = baseTypeToQname(baseType, params, false);
		if (qname == "*") {
			return qname;
		}
		if (options != null && options.renameSymbols != null) {
			var renameSymbols = options.renameSymbols;
			var i = 0;
			while (i < renameSymbols.length) {
				var originalName = renameSymbols[i];
				i++;
				var newName = renameSymbols[i];
				i++;
				if (originalName == qname) {
					qname = newName;
					break;
				}
			}
		}

		if (QNAMES_TO_REWRITE.exists(qname)) {
			qname = QNAMES_TO_REWRITE.get(qname);
		}

		var unqualifiedName = qname;
		var index = unqualifiedName.lastIndexOf(".");
		if (index != -1) {
			unqualifiedName = unqualifiedName.substr(index + 1);
		}

		if (!includeParams || params.length == 0 || qname != "Vector") {
			return unqualifiedName;
		}

		var buffer = new StringBuf();
		buffer.add(unqualifiedName);
		buffer.add(generateQnameParams(params));
		return buffer.toString();

		return qname;
	}

	private function abstractTypeToQname(abstractType:AbstractType, abstractTypeParams:Array<Type>, includeParams:Bool = true):String {
		var pack = abstractType.pack;
		if (abstractType.name == "Null" && pack.length == 0) {
			var result = macroTypeToQname(abstractTypeParams[0]);
			if (NON_NULLABLE_AS3_TYPES.indexOf(result) != -1) {
				// the following types can't be simplified by removing Null<>
				// so return Object instead:
				// Null<Bool>, Null<Float>, Null<Int>, Null<UInt>
				return "Object";
			}
			return result;
		}
		if (abstractType.name == "Function" && abstractType.pack.length == 1 && abstractType.pack[0] == "haxe") {
			return "Function";
		}
		var underlyingType = abstractType.type;
		switch (underlyingType) {
			case TAbstract(t, underlyingParams):
				var result = baseTypeToQname(abstractType, abstractTypeParams, false);
				var compareTo = baseTypeToQname(t.get(), underlyingParams, false);
				if (result == compareTo) {
					// this avoids an infinite loop
					return baseTypeToQname(abstractType, abstractTypeParams, includeParams);
				}
			default:
		}
		
		if (includeParams && abstractTypeParams.length > 0) {
			var abstractTypeQname = baseTypeToQname(abstractType, abstractTypeParams, false);
			if (abstractTypeQname == "Vector")
			{
				var paramsToInclude:Array<Type> = null;
				switch (underlyingType) {
					case TInst(t, underlyingTypeParams):
						paramsToInclude = underlyingTypeParams.map((param) -> {
							return translateTypeParam(param, abstractTypeQname, abstractType.params, abstractTypeParams);
						});
					case TAbstract(t, underlyingTypeParams):
						paramsToInclude = underlyingTypeParams;
					case TEnum(t, underlyingTypeParams):
						paramsToInclude = underlyingTypeParams;
					case TType(t, underlyingTypeParams):
						paramsToInclude = underlyingTypeParams;
					default:
						paramsToInclude = [];
				}
				return macroTypeToQname(underlyingType, false) + generateQnameParams(paramsToInclude);
			}
		}
		return macroTypeToQname(underlyingType, includeParams);
	}
	
	private function translateTypeParam(typeParam:Type, typeParametersQname:String, typeParameters:Array<TypeParameter>, params:Array<Type>):Type {
		switch (typeParam) {
			case TInst(t, _):
				var classType = t.get();
				switch (classType.kind) {
					case KTypeParameter(constraints):
						var typeParamSourceQname = classType.pack.join(".");
						if (QNAMES_TO_REWRITE.exists(typeParamSourceQname)) {
							typeParamSourceQname = QNAMES_TO_REWRITE.get(typeParamSourceQname);
						}
						if (typeParamSourceQname == typeParametersQname) {
							for (j in 0...typeParameters.length) {
								var param = typeParameters[j];
								if (param.name == classType.name) {
									return params[j];
								}
							}
						}
					default:
				}
			default:
		}
		return typeParam;
	}

	private function writeGenerated(outputDirPath:String, baseType:BaseType, generated:String):Void {
		var outputFilePath = getFileOutputPath(outputDirPath, baseType);
		FileSystem.createDirectory(Path.directory(outputFilePath));
		var fileOutput = File.write(outputFilePath);
		fileOutput.writeString(generated);
		fileOutput.close();
	}

	private function getFileOutputPath(dirPath:String, baseType:BaseType):String {
		var qname = baseTypeToQname(baseType, [], false);
		var relativePath = qname.split(".").join("/") + ".as";
		return Path.join([dirPath, relativePath]);
	}

	/**
		Haxe allows classes to implement methods from interfaces with more
		specific types, but AS3 does not. This method finds the original types
		from the interface that are required to match.
	**/
	private function findInterfaceArgsAndRet(classField:ClassField, classType:ClassType,
			argsAndRet:{args:Array<{name:String, opt:Bool, t:Type}>, ret:Type}):Void {
		var currentClassType = classType;
		while (currentClassType != null) {
			for (currentInterface in currentClassType.interfaces) {
				for (interfaceField in currentInterface.t.get().fields.get()) {
					if (interfaceField.name == classField.name) {
						switch (interfaceField.kind) {
							case FMethod(k):
								switch (interfaceField.type) {
									case TFun(interfaceArgs, interfaceRet):
										argsAndRet.args = interfaceArgs;
										argsAndRet.ret = interfaceRet;
										return;
									default:
								}
							case FVar(read, write):
								argsAndRet.ret = interfaceField.type;
							default:
						}
					}
				}
			}

			if (currentClassType.superClass != null) {
				currentClassType = currentClassType.superClass.t.get();
			} else {
				currentClassType = null;
			}
		}
	}
}

typedef AS3GeneratorOptions = {
	/**
		Externs will be generated for symbols in the specified packages only,
		and no externs will be generated for symbols in other packages.

		Types from other packages may still be referenced by fields or method
		signatures. Use `allowedPackageReferences` to restrict those too.
	**/
	?includedPackages:Array<String>,

	/**
		When `includedPackages` is not empty, `allowedPackageReferences` may
		be used to allow types from other packages to be used for field types,
		method parameter types, and method return types. Otherwise, the types
		will be replaced with AS3's `*` type.
			
		All package references are allowed by default. If in doubt, pass an
		empty array to restrict all types that don't appear in
		`includedPackages`.
	**/
	?allowedPackageReferences:Array<String>,

	/**
		Gives specific symbols new names. Alternates between the original symbol
		name and its new name.
	**/
	?renameSymbols:Array<String>,

	/**
		Optionally exclude specific symbols.
	**/
	?excludeSymbols:Array<String>,

	/**
		The target directory where externs files will be generated.
	**/
	?outputPath:String
}
