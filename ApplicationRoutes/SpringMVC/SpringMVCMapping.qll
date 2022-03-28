import java
import semmle.code.java.dataflow.DataFlow
import semmle.code.java.dataflow.FlowSources
import semmle.code.java.frameworks.spring.SpringController


/**
* 重新为类型设置默认值
*/
string getADefaultValue(Type t) {
    t.getName() = "boolean" and result = "true"
    or
    t.getName() = "char" and result = "'\\0'"
    or
    t.getName().regexpMatch("(float|double|int|short|byte|long)") and result = "0"
}

/**
* 为枚举类型将字段返回
*/
string getEnumField(Class c){
    exists(Field f | 
    c instanceof EnumType
    and f = c.getAField()
    and f.getType().(RefType) = c
    and result = f.getName()
    )
}

/**
* 设置参数不同数据类型的默认值，设置了基本类型、String类型
*/
string stringParamValue(Type type){
    exists(BoxedType boxedType, PrimitiveType primitiveType, string value|
    (
        ((type = primitiveType or (type = boxedType and boxedType.getPrimitiveType() = primitiveType))
            and value = getADefaultValue(primitiveType).toString())
        or (type.hasName(["StringBuilder", "StringBuffer", "String", "StringJoiner"]) and value = "test")
        or (type.hasName(["BigInteger", "BigDecimal"]) and value = "0")
    )
    // and m instanceof SpringControllerMethod
    and result = value
    )
}


// 参数没有使用@RequestParam注解，则会调用该谓词。为以下类型参数设置默认值
string paramParseNoRequestParam(Type t){
    (
        t.(RefType).getAnAncestor().getSourceDeclaration().hasQualifiedName("org.springframework.web.multipart", "MultipartHttpServletRequest")
        and result = "ParamIsRandom_MultipartHttpServletRequest=filename.jpg"
    ) or (
        t.(RefType).getAnAncestor().getSourceDeclaration().hasQualifiedName("java.io", "InputStream")
        and result = "ParamIsRandom_InputStream=test"
    ) or (
        t.(RefType).getAnAncestor().getSourceDeclaration().hasQualifiedName("org.springframework.core.io", "InputStreamResource")
        and result = "ParamIsRandom_InputStreamResource=test"
    ) or (
        t.(RefType).getAnAncestor().getSourceDeclaration().hasQualifiedName("org.springframework.core.io", "ByteArrayResource")
        and result = "ParamIsRandom_ByteArrayResource=test"
    ) or (
        t.(RefType).getAnAncestor().getSourceDeclaration().hasQualifiedName("java.io", "Reader")
        and result = "ParamIsRandom_Reader=test"
    )
}


// 为以下类型参数设置默认值
bindingset[param]
string paramParse(Type t, string param){
    (
        // 直接为基本类型等设置默认值
        result = param + "_" + t.getName() + "=" + stringParamValue(t)
    ) or (
        // 参数类型为List<MultipartFile>
        t.(ParameterizedType).getTypeArgument(0).getAnAncestor().getSourceDeclaration().hasQualifiedName("org.springframework.web.multipart", "MultipartFile")
        and result = param + "_Multipart=filename.jpg"
    ) or (
        // 参数类型为MultipartFile
        t.(RefType).getAnAncestor().getSourceDeclaration().hasQualifiedName("org.springframework.web.multipart", "MultipartFile")
        and result = param + "_Multipart=filename.jpg"
    ) or (
        // String[]等数组类型
        result = param + "_Array_" + t.(Array).getElementType().getName() + "=" + stringParamValue(t.(Array).getElementType())
    )  or (
        // List类型并且使用了泛型
        t.(ParameterizedType).getGenericType().getAnAncestor().getSourceDeclaration().hasQualifiedName("java.util", "List")
        and result = param + "_List_" + t.(ParameterizedType).getTypeArgument(0).getName() + "=" + stringParamValue(t.(ParameterizedType).getTypeArgument(0))
    ) 
    or (
        // Map类型并且使用了泛型
        t.(ParameterizedType).getGenericType().getAnAncestor().getSourceDeclaration().hasQualifiedName("java.util", "Map")
        and result = param + "_Map[" + stringParamValue(t.(ParameterizedType).getTypeArgument(0)) + "]_" + t.(ParameterizedType).getTypeArgument(1).getName() + "=" + stringParamValue(t.(ParameterizedType).getTypeArgument(1))

    ) or (
        // List类型没有使用泛型
        t.(RefType).getAnAncestor().getSourceDeclaration().hasQualifiedName("java.util", "List")
        and not t.(ParameterizedType).getGenericType().getAnAncestor().getSourceDeclaration().hasQualifiedName("java.util", "List")
        and result = param + "_List_String=test"
    ) or (
        // Map类型没有使用泛型
        t.(RefType).getAnAncestor().getSourceDeclaration().hasQualifiedName("java.util", "Map")
        and not t.(ParameterizedType).getGenericType().getAnAncestor().getSourceDeclaration().hasQualifiedName("java.util", "Map")
        and result = param + "_Map_String=test"
    )
    // Enum类型
    or exists(Class c |
        t = c
        and c instanceof EnumType
        and result = param + "_Enum=" + concat(string i| i in [getEnumField(c)] | i, "/")
    )
}

// 为Date类型参数设置默认值
bindingset[bool]
string paramDateParse(Type t, Annotation a, boolean bool){
    (
        a.toString() = "DateTimeFormat"
        and a.getValue("pattern").(CompileTimeConstantExpr).getStringValue().matches("yyyy/MM/dd%")
        and result = "_Date=2022/11/11 11:11:11"
    ) or (
        a.toString() = "DateTimeFormat"
        and a.getValue("pattern").(CompileTimeConstantExpr).getStringValue().matches("yyyy-MM-dd%")
        and result = "_Date=2022-11-11 11:11:11"
    ) or (
        a.toString() = "DateTimeFormat"
        and a.getValue("pattern").toString() = "\"\""
        and result = "_Date=2022-11-11 11:11:11"
    ) or (t.(RefType).hasQualifiedName("java.util", "Date")
        // and not a.toString() = "DateTimeFormat"
        and bool = true
        and result = "_Date=2022/11/11 11:11:11"
    )
}


// 当为List类型并且使用了泛型为Date类型，那么为这种情况调用paramDateParse谓词处理
bindingset[param, bool]
string paramDateListParse(Type t, string param, Annotation a, boolean bool){
    (
        t.(ParameterizedType).getGenericType().getAnAncestor().getSourceDeclaration().hasQualifiedName("java.util", "List")
        and result = param + "_List" + paramDateParse(t, a, bool)
    ) or (
        not t.(ParameterizedType).getGenericType().getAnAncestor().getSourceDeclaration().hasQualifiedName("java.util", "List")
        and result = param + paramDateParse(t, a, bool)
    )
}




class MappingMethod extends Method{

    MappingMethod(){
        // this instanceof SpringControllerMethod
        this instanceof Method
         and this.fromSource()
    }

    /**
     * 获取当前方法所处的Controller
    */
    Class getController(){
        result = this.getDeclaringType()
    }

    /**
    * 获取Controller对应的映射路径
    * 
    * NOTE: 可能并没有配置
    */
    string getControllerMappedPath(){
        if 
            getController().getAnAnnotation().getType() instanceof SpringRequestMappingAnnotationType
        then
            exists(Annotation a | a = getController().getAnAnnotation() and a.getType() instanceof SpringRequestMappingAnnotationType
            and result = a.getValue(["value","path"]).(CompileTimeConstantExpr).getStringValue() )
        else
            result = ""
    }

    // 再次处理PathVariable/MatrixVariable注解的情况
    // 代码逻辑和gethandlePath谓词基本一样
    // 当出现多个{path}的时候，前面只能处理2个，这里再调用一次则处理3个，再多的情况不考虑了
    // 如果需要，可以再添加一个方法调用当前方法
    string gethandlePathTwo(){
        exists(string d |  
            concat(string i| i in [gethandlePath()] | i.toString() , "&") = d
            and if d.indexOf("_Param") > -1 and d.indexOf("{") > -1 
            then
            exists(string a , string b,  string g2, string c, string d1, string out| 
                concat(string i| i in [gethandleMVNo(d)] | i.toString() , "&") = out and
                a = concat(string i| i in [d] | i.toString() , "&").splitAt("&")
                and b = any(a.regexpFind("\\{([a-zA-Z0-9]+)\\}", _, _))
                and ((out.indexOf(";") > -1
                    and g2 = any(string aa | 
                        aa =  [out.splitAt("&")]
                        | aa.regexpFind(b.substring(1, b.length() -1) + "_[a-zA-Z]+" + "_Param"+ ";([;a-zA-Z0-9=_]+)", _, _)
                        )
                ) or (not out.indexOf(";") > -1
                and g2 = any(string aa | 
                    aa =  [out.splitAt("&")]
                    | aa.regexpFind(b.substring(1, b.length() -1) + "_[a-zA-Z]+" + "_Param", _, _)
                        )
                    ))

                and c = a.regexpFind("\\{([a-zA-Z0-9]+)\\}", _, _)
                and c = "{" + g2.substring(0, c.length()-2) + "}"
                and d1 = a.replaceAll(c, g2)
                and result = d1
            )
            else
                result = d
            )
    }


    // 主要处理MatrixVariable注解没有pathVar的情况
    bindingset[d]
    string gethandleMVNo(string d){
        if d.indexOf("^^^") > -1
        then
        // 存在多个没有pathVar的情况则通过&&将其拼接在一起，并且使其只能出现一次，不然合并之后会导致每个点后面都会带上该参数
        // 如：/path;foo1=123;foo2=456/path1;foo1=123;foo2=456
        // 这种情况肯定是不想出现的
        exists(string b,  string dd, string t, string copyd, string groupd ,string pp11 | 
            b = concat(string i| i in [d.regexpFind(";([a-zA-Z0-9=_]+\\^\\^\\^)", _, _)] | i.toString() , "&&")
            and groupd=b.replaceAll("&&", "").replaceAll("^^^", "")
            and (dd.indexOf("&&") > -1 or not dd.indexOf("^^^") > -1)
            and t in [d.splitAt("&")] and  dd =t.replaceAll(b.splitAt("&&"), groupd)
            and copyd = d.replaceAll(b.splitAt("&&"), groupd).replaceAll(b.splitAt("&&"), groupd).replaceAll(b.splitAt("&&"), groupd)
            and not copyd.indexOf("^^^") > -1
            and exists(int ii, string newop | 
                min(copyd.indexOf(groupd)) =ii
                and exists(string x, int x1, int x2 | x in [copyd.splitAt("&")] and copyd.indexOf(x) = x1 
                and x.indexOf(groupd) = x2 and ii = x2+x1 and x = newop)

                and (newop = pp11 or (dd.replaceAll(groupd, "")=pp11 and pp11 != newop.replaceAll(groupd, "")))
            )
            and result = pp11
        )
        else
            result = d
    }

    // 处理path，比如/{path};foo，则可以生成正常的/path;foo=1
    string gethandlePath(){
        exists(string d |  
        concat(string i| i in [getMethodMappedPath()] | i.toString() , "&") = d
        and if (d.indexOf("_Param") > -1 and d.indexOf("{") > -1) or(d.indexOf("_Param") > -1 and d.indexOf("^^^") > -1)
        then
            // 如果存在PathVariable/MatrixVariable注解的情况会进入这里
            if d.indexOf("^^^") > -1 and not d.indexOf("{") > -1
            then
                // 如果只有MatrixVariable并且没有指定pathVar则把^^^特征剔除掉
                result = gethandleMVNo(d)
            else
                // newb为：/entity4/{path1}/path2_Param;ee^^^/{path3}中的{path1}、{path3}
                // pp11为：/entity4/{path1}/path2_Param;ee^^^/{path3}&/entity4/{path1}/{path2}/path3_Param;ee^^^&/entity4/path1_Param;bb/{path2}/{path3}
                // g2为：path2_Param;ee
                exists(string newb, string g2, string c, string d1, string pp11, string out |
                    concat(string i| i in [gethandleMVNo(d)] | i.toString() , "&") = out
                    and pp11 = out.splitAt("&")
                    and newb = any(pp11.regexpFind("\\{([a-zA-Z0-9]+)\\}", _, _))
                    
                    and ((out.indexOf(";") > -1
                        and g2 = any(string aa | 
                            aa =  [out.splitAt("&")]
                            | aa.regexpFind(newb.substring(1, newb.length() -1) + "_[a-zA-Z]+"  + "_Param"+ ";([;a-zA-Z0-9=_]+)", _, _)
                            )
                    ) or (not out.indexOf(";") > -1
                    and g2 = any(string aa | 
                        aa =  [out.splitAt("&")]
                        | aa.regexpFind(newb.substring(1, newb.length() -1) + "_[a-zA-Z]+" + "_Param", _, _)
                            )
                        ))

                    and c = pp11.regexpFind("\\{([a-zA-Z0-9_]+)\\}", _, _)
                    and c = "{" + g2.substring(0, c.length()-2) + "}"
                    and d1 = pp11.replaceAll(c, g2)
                    and result = d1
                )
        else
            //直接返回
            result = d
        )
    }

    // 这个方法主要用来处理存在MatrixVariable注解的情况
    // TODO：pathVar为空情况可能存在value或者name，需要处理下该情况
    bindingset[pathstring, pathVar]
    string getMatrixVariableParam(string pathstring, string pathVar){
        exists(Parameter p, Method m, string pathName | 
            m = this and 
            p = m.getAParameter()
            and pathName = pathVar.prefix(pathVar.indexOf("_"))
            and if m.getAParameter().getAnAnnotation().toString() = "MatrixVariable"
            then
                // 使用MatrixVariable注解，pathVar和传入的pathVar匹配
                (exists(Expr e, Annotation annotation | 
                    p.getAnAnnotation().getValue("pathVar").(CompileTimeConstantExpr).getStringValue() = pathName
                    and e.getParent().toString() = "MatrixVariable"
                    and e.getEnclosingCallable() = m
                    and ((e = p.getAnAnnotation().getValue(["value", "name"])
                        and e.toString() != "\"\""
                        and result = pathstring.replaceAll("{" + pathName + "}", pathVar + "_Param" + ";" + e.(CompileTimeConstantExpr).getStringValue() + "_" + p.getType().getName() + "=" + stringParamValue(p.getType()))
                    ) or (result = pathstring.replaceAll("{" + pathName + "}", pathVar + "_Param" + ";" +  p.toString() + "_" + p.getType().getName() + "=" + stringParamValue(p.getType()))
                        and annotation = p.getAnAnnotation()
                        and annotation.toString() = "MatrixVariable"
                        and "" = annotation.getValue("value").(CompileTimeConstantExpr).getStringValue()
                        and "" = annotation.getValue("name").(CompileTimeConstantExpr).getStringValue()
                        )
                        )
                    )
                // 处理当使用MatrixVariable注解但没有通过pathVar指定PathVariable绑定的变量，则通过如下方式处理，标记^^^
                // 因为这种情况比较特殊，可以跟在当前任一路径点后面作为参数
                ) or (exists(Annotation annotation | 
                    result = pathstring.replaceAll("{" + pathName + "}", pathVar + "_Param" + ";"+  p.toString() + "_" + p.getType().getName() + "=" + stringParamValue(p.getType()) + "^^^")
                    and not annotation.getValue("pathVar").toString().regexpFind("[a-zA-Z0-9]+", _, _) = ""
                    and not m.getAParameter().getAnAnnotation().getValue("pathVar").(CompileTimeConstantExpr).getStringValue() = pathName
                    and "" = annotation.getValue("value").(CompileTimeConstantExpr).getStringValue()
                    and "" = annotation.getValue("name").(CompileTimeConstantExpr).getStringValue()
                    and annotation = p.getAnAnnotation()
                    and annotation.toString() = "MatrixVariable"
                    )
                )
            else
                // 不存在MatrixVariable注解时，{}占位的路径名添加_Param标记
                result = pathstring.replaceAll("{" + pathName + "}", pathVar + "_Param")
        )
    }

    /**
     * 获取当前方法对应的映射路径
    */
    string getMethodMappedPath(){
        exists(Annotation a, Parameter p, string pathstring | 
            a = getAnAnnotation() and a.getType() instanceof SpringRequestMappingAnnotationType
            and pathstring = a.getValue(["value","path"]).(CompileTimeConstantExpr).getStringValue() 
            and if pathstring.indexOf("{") > -1
            then
                exists(string pathVar |  
                    p = this.getAParameter()
                    and p.getAnAnnotation().toString() = "PathVariable"
                    and pathVar = p.toString() + "_" + p.getType().getName()
                    // 这里会调用方法处理存在MatrixVariable注解的情况
                    and getMatrixVariableParam(pathstring, pathVar) = result
                )
            else
                result = pathstring
        )
    }

    /**
     * 格式化映射的路径
     * 
     * 统一前面有路径分割符，后面没有路径分隔符
    */
    bindingset[path]
    private string formatMappedPath(string path){
        // 1. /path/ => /path
        (path.matches("/%") and path.matches("%/") and result = path.prefix(path.length()-1))
        or    
        // 2. /path => /path
        (path.matches("/%") and not path.matches("%/") and result = path)
        or
        // 3. path/ => /path
        (not path.matches("/%") and path.matches("%/") and result = "/"+path.prefix(path.length()-1))
        or
        // 4. path => /path
        (not path.matches("/%") and not path.matches("%/") and result = "/"+path)
    }


    string getMappedPath(){
        result = (formatMappedPath(getControllerMappedPath()) + formatMappedPath(gethandlePathTwo())).replaceAll("//", "/")
    }

}

// 处理Content-Type
class RequestContentType extends Method{
    RequestContentType(){
        // this instanceof SpringControllerMethod
        this instanceof Method
    }


    /**
     * 获取ContentType，如果函数参数有RequestBody注解则判定为json
     * 如果Mapping注解中存在consumes值并且不为空，则值为content-type
     * 其他情况则默认为application/x-www-form-urlcoded
    */
    string getContentType(){
        (
            this.getAParameter().getAnAnnotation().getType().hasQualifiedName("org.springframework.web.bind.annotation", "RequestBody")
            and result = "Content-Type: application/json"
        ) or (
                    result = "Content-Type: " + this.getAnAnnotation().getValue("consumes").getAChildExpr().(CompileTimeConstantExpr).getStringValue().toLowerCase().trim()
                    or result = "Content-Type: " +  this.getAnAnnotation().getValue("consumes").(CompileTimeConstantExpr).getStringValue().toLowerCase().trim()
                )
        or (if this.getAnAnnotation().toString() = "GetMapping" or this.getAParameter().getAnAnnotation().getType().hasQualifiedName("org.springframework.web.bind.annotation", "RequestBody")
            then result = ""
            else not exists(string contentType | 
                (
                    contentType = this.getAnAnnotation().getValue("consumes").getAChildExpr().(CompileTimeConstantExpr).getStringValue().toLowerCase().trim()
                    or contentType = this.getAnAnnotation().getValue("consumes").(CompileTimeConstantExpr).getStringValue().toLowerCase().trim()
                ) and contentType != ""
            ) and result = "Content-Type: application/x-www-form-urlcoded"
        )
    }

}


// 处理请求Method不同类型
class RequestMethodType extends Method{
    RequestMethodType(){
        // this instanceof SpringControllerMethod
        this instanceof Method
    }


    Class getController(){
        result = this.getDeclaringType()
    }



    string getControllerMethodType(){

        exists(Annotation a | a = getAnAnnotation() 
        and (((a.getValue(["method"]).toString().matches("%GET") or a.getValue(["method"]).getAChildExpr().toString().matches("%GET") or a.getType().toString() = "GetMapping") and result = "GET")
        or ((a.getValue(["method"]).toString().matches("%POST") or a.getValue(["method"]).getAChildExpr().toString().matches("%POST") or a.getType().toString() = "PostMapping") and result = "POST")
        or ((a.getValue(["method"]).toString().matches("%PUT") or a.getValue(["method"]).getAChildExpr().toString().matches("%PUT") or a.getType().toString() = "PutMapping") and result = "PUT")
        or ((a.getValue(["method"]).toString().matches("%DELETE") or a.getValue(["method"]).getAChildExpr().toString().matches("%DELETE") or a.getType().toString() = "DeleteMapping") and result = "DELETE")
        or (not "method" in [getAnnotationMethodName(a)] and a.getType().toString() = "RequestMapping" and result = "GET/POST")
        ))
    }


    
    /**
     * 用来筛选注解中有使用的参数名
    */
    string getAnnotationMethodName(Annotation a){
        exists(Expr e | 
         (e = a.getAValue("method") and result = "method")
         or (e = a.getAValue("value") and result = "value")
         or (e = a.getAValue("params") and result = "params")
         or (e = a.getAValue("headers") and result = "headers")
         or (e = a.getAValue("consumes") and result = "consumes")
         or (e = a.getAValue("produces") and result = "produces")
        )
    }

    string getMethodMethodType(){
        if 
          getAnAnnotation().getType() instanceof SpringRequestMappingAnnotationType
        then
        exists(Annotation a | a = getAnAnnotation() 
        and (((a.getValue(["method"]).toString().matches("%GET") or a.getValue(["method"]).getAChildExpr().toString().matches("%GET") or a.getType().toString() = "GetMapping") and result = "GET")
        or ((a.getValue(["method"]).toString().matches("%POST") or a.getValue(["method"]).getAChildExpr().toString().matches("%POST") or a.getType().toString() = "PostMapping") and result = "POST")
        or ((a.getValue(["method"]).toString().matches("%PUT") or a.getValue(["method"]).getAChildExpr().toString().matches("%PUT") or a.getType().toString() = "PutMapping") and result = "PUT")
        or ((a.getValue(["method"]).toString().matches("%DELETE") or a.getValue(["method"]).getAChildExpr().toString().matches("%DELETE") or a.getType().toString() = "DeleteMapping") and result = "DELETE")
        or (not "method" in [getAnnotationMethodName(a)] and a.getType().toString() = "RequestMapping" and result = "GET/POST")
        ))

        else
          result = ""
      }

      string getMethodType(){
        result = getMethodMethodType() and
        if result = ""
        then result = getControllerMethodType()
        else result = result

      }

}

/**
 * 4.1) 定义request对象参数污点跟踪
*/
class RequestParamTaintConfig extends TaintTracking::Configuration {
    RequestParamTaintConfig() { this = "RequestParamTaintConfig" }
 
    override predicate isSource(DataFlow::Node source) {
        exists(SpringControllerMethod scm | 
            scm = source.asExpr().getEnclosingCallable()
            )
        }

    override predicate isSink(DataFlow::Node sink) {
        sink instanceof RemoteFlowSource

        // 有调用request.getParts方法并且该request对象类型为HttpServletRequest或其子类，，那么会作为sink
        or exists(MethodAccess ma, Interface interface |
            interface.getAnAncestor().hasQualifiedName("javax.servlet.http", "HttpServletRequest")
            
            and ma.getEnclosingCallable() = sink.getEnclosingCallable()
            and ma.getMethod().hasName("getParts")
            and ma.getMethod().hasNoParameters()

            and ma.getQualifier().getType() = interface
            and ma.getMethod().overridesOrInstantiates*(interface.getAMethod())
            and sink.asExpr() = ma
        )
    }

    override predicate isAdditionalTaintStep(DataFlow::Node src, DataFlow::Node sink){
        exists(MethodAccess ma |
            (ma.getMethod() instanceof GetterMethod or ma.getMethod() instanceof SetterMethod or ma.getMethod().getName().matches("get%") or ma.getMethod().getName().matches("set%"))
            and
             src.asExpr() = ma.getQualifier()
            and sink.asExpr() = ma
            )
    }
 
}


/**
 * 3-1.1) 跟踪有调用entity类中getter方法
*/
class EntityParamTaintConfig extends TaintTracking::Configuration {
    EntityParamTaintConfig() { this = "EntityParamTaintConfig" }
 
    override predicate isSource(DataFlow::Node source) {
         source instanceof RemoteFlowSource
        and not source.asParameter().getType() instanceof PrimitiveType and not source.asParameter().getType() instanceof NumberType and not source.asParameter().getType().toString() = "String" and not source.asParameter().getType() instanceof BoxedType
    }

    override predicate isSink(DataFlow::Node sink) {
        exists(MethodAccess ma | 
            sink.asExpr() = ma
            and ma.getQualifier().getType() = sink.getEnclosingCallable().getAParameter().getType()
            )
    }

    override predicate isAdditionalTaintStep(DataFlow::Node src, DataFlow::Node sink){
        exists(MethodAccess ma |
            (ma.getMethod() instanceof GetterMethod or ma.getMethod() instanceof SetterMethod or ma.getMethod().getName().matches("get%") or ma.getMethod().getName().matches("set%"))
            and
             src.asExpr() = ma.getQualifier()
            and sink.asExpr() = ma
            )
    }
 
}



class SpringMVCMapping extends string{

    SpringMVCMapping(){
        this = ""
    }


    /**
     * 1) 如果参数有RequestParam注解并且value值不为空，则参数为其value值
     * TODO：需要考虑参数类型
    */  
   string getRequestParam(Method m){
        exists(Parameter p, Expr e, Annotation a | 
            p = m.getAParameter()
            and a = p.getAnAnnotation()
            and a.getType().hasQualifiedName("org.springframework.web.bind.annotation", "RequestParam")
            and e = a.getValue("value")
            and e.getParent().toString() = "RequestParam"
            and ((
                // 当RequestParam注解的value不为空 / 参数类型不为MultipartFile / 参数类型为基本类型、String类型并且考虑了数组以及List泛型、Map泛型、Date情况(未考虑Set)
                e.toString() != "\"\""
                // and not p.getType().hasName("MultipartFile")
                and (result = paramParse(p.getType(), e.(CompileTimeConstantExpr).getStringValue())
                    or exists(boolean bool | result = paramDateListParse(p.getType(), e.(CompileTimeConstantExpr).getStringValue(), p.getAnAnnotation(), bool)
                        and bool = any(boolean inBool | (not p.hasAnnotation("org.springframework.format.annotation", "DateTimeFormat") and inBool=true)
                            or (p.hasAnnotation("org.springframework.format.annotation", "DateTimeFormat") and inBool=false)
                            )
                        )
                )
            ))
        )
    }

    /**
     * 1.1) 在当前类中有方法使用了ModelAttribute注解，并且存在相应的情况来依次获取请求参数
     *      不考虑ModelAttribute注解使用在方法参数前，这种情况对于我们来说没什么区别无需额外处理
    */  
    string getRequestParamModelAttribute(Method m){
        // m instanceof SpringRequestMappingMethod and

        exists(Method newM |
            newM = m.getDeclaringType().getAMethod()
            and not newM = m
            and newM.getAnAnnotation().getType().hasQualifiedName("org.springframework.web.bind.annotation", "ModelAttribute")
            // 只有当当前方法有定义Model类型的参数或者其子类，那么可能存在从Model中获取属性则有必要获取请求参数
            // 另一种情况是使用ModelAttribute注解的方法其中参数有使用到RequestParam注解那么必须获取该参数作为请求参数
            and (exists(Type t | t = m.getAParamType() and t.(RefType).getAnAncestor().hasQualifiedName("org.springframework.ui", "Model"))
                or newM.getAParameter().getAnAnnotation().getType().hasQualifiedName("org.springframework.web.bind.annotation", "RequestParam"))
            and (result = getRequestParam(newM)
                or result = getFuncParam(newM)
                or result = getFuncBlockParam(newM)
                or result = getFlowParam(newM)
            )
        )
        // 在当前方法的类中没有使用到ModelAttribute注解定义的方法，则使用默认谓词
        or result = getRequestParam(m)
    }


    /**
     * 2) 从controller方法体中获取参数
     * 这部分不太好确定参数类型，getParameter取出来的都默认认定为String
    */
    string getFuncBlockParam(Method m){
        exists(Parameter p, MethodAccess ma, Interface interface | 
            p = m.getAParameter()
            and (interface.getAnAncestor().hasQualifiedName("javax.servlet", "ServletRequest")
                or interface.getAnAncestor().hasQualifiedName("org.springframework.web.context.request", "WebRequest")
            )
            and ma.getMethod().overridesOrInstantiates*(interface.getAMethod())
            and  (
                (ma.getMethod().hasName("getParameter") and ma.getCaller() = m and ma.getQualifier() = p.getAnAccess()
                and result = ma.getArgument(0).(CompileTimeConstantExpr).getStringValue() + "_String=test")
                or (ma.getMethod().hasName("getInputStream") and ma.getCaller() = m and ma.getQualifier() = p.getAnAccess()
                    and ma.getMethod().hasNoParameters() 
                    and result = "ParamIsRandom_InputStream=test")
            )
        )
        or 
        exists(TypeAccess ta | 
            ta.getEnclosingCallable() = m
            and ta.getType().hasName("MultipartHttpServletRequest")
            and result = "ParamIsRandom_Multipart=filename.jpg"
        )
        // 调用request.getParts()方法进行文件上传
        or exists(MethodAccess ma, Interface interface |
            interface.getAnAncestor().hasQualifiedName("javax.servlet.http", "HttpServletRequest")
            and ma.getEnclosingCallable() = m
            and ma.getMethod().hasName("getParts")
            and ma.getMethod().hasNoParameters()

            and ma.getMethod().overridesOrInstantiates*(interface.getAMethod())
            and result = "ParamIsRandom_Multipart=filename.jpg"
        )

        // )
    }

    /**
     * 3) 从controller方法参数中获取，分为基本类型等、请求参数封装在entity对象中
    */
    string getFuncParam(Method m){
        // m.getDeclaringType().hasQualifiedName("org.springframework.samples.mvc.mapping", "ClasslevelMappingController") and
    (
        m instanceof SpringRequestMappingMethod and
        
        not m.hasNoParameters() and
        exists(Parameter p |  p = m.getAParameter() and
        (
            // 之所以这里用if判断，因为基本上不会entity类接收参数又用基本类型再接收参数，排除这种情况(如果想考虑这种情况，可以自行修改代码)
            if (not p.getType() instanceof PrimitiveType
                and not p.getType() instanceof BoxedType
                and not p.getType() instanceof NumberType
                and not p.getType().toString() in ["Date",
                    "StringBuilder", "StringBuffer",
                    "String", "StringJoiner",
                    "BigInteger", "BigDecimal",
                    "Reader", "InputStream",
                    "MultipartFile"]
                and not p.getType().(Array).getElementType() instanceof PrimitiveType
                and not p.getType().(Array).getElementType() instanceof BoxedType
                and not p.getType().(Array).getElementType() instanceof NumberType
                and not p.getType().(Array).getElementType().toString() in ["Date",
                    "StringBuilder", "StringBuffer",
                    "String", "StringJoiner",
                    "BigInteger", "BigDecimal",
                    "Reader", "InputStream",
                    "MultipartFile"]
                and not p.getType() instanceof EnumType
                and not p.getType().(RefType).getAnAncestor().getSourceDeclaration().hasQualifiedName("java.util", "MultipartRequest")
                and not p.getType().(RefType).getAnAncestor().getSourceDeclaration().hasQualifiedName("java.util", "Map")
                and not p.getType().(RefType).getAnAncestor().getSourceDeclaration().hasQualifiedName("java.util", "List")
                and not p.getType().(ParameterizedType).getAnAncestor().getSourceDeclaration().hasQualifiedName("java.util", "Map")
                and not p.getType().(ParameterizedType).getAnAncestor().getSourceDeclaration().hasQualifiedName("java.util", "List")
                and not p.getType().(ParameterizedType).getGenericType().getAnAncestor().hasQualifiedName("org.springframework.http", "HttpEntity")
                ) or (p.getType().(ParameterizedType).getGenericType().getAnAncestor().hasQualifiedName("org.springframework.http", "HttpEntity")
                    and not p.getType().(ParameterizedType).getTypeArgument(0) instanceof BoxedType
                    and not p.getType().(ParameterizedType).getTypeArgument(0) instanceof NumberType
                    and not p.getType().(ParameterizedType).getTypeArgument(0).toString() in ["Date",
                        "StringBuilder", "StringBuffer",
                        "String", "StringJoiner",
                        "BigInteger", "BigDecimal",
                        "Reader", "InputStream",
                        "MultipartFile"]
                )
            then
                (
                    (
                        exists(Class c | 
                            (
                                not c.fromSource() and result = getNotFromSourceParam(c) and c = p.getType()
                            )

                            or (c.fromSource()
                                and exists(Field f, FieldWrite fw, Constructor cs | 
                                    // 去除一些不可能是自定义的Entity类
                                    (
                                        (not p.getType().(RefType).getAnAncestor().getQualifiedName() in ["org.springframework.ui.Model", 
                                            "org.springframework.validation.BindingResult", 
                                            "org.springframework.validation.Errors", 
                                            "org.springframework.web.bind.support.SessionStatus", 
                                            "java.security.Principal"
                                            ]
                                        )
                                    )

                                    and (c = p.getType()
                                        or (c = p.getType().(ParameterizedType).getTypeArgument(0)
                                            and p.getType().(RefType).getAnAncestor().getSourceDeclaration().hasQualifiedName("org.springframework.http", "HttpEntity")
                                        )
                                    )
                                    and f = c.getAField()
                                    and cs = c.getAConstructor()
                                    and fw.getField() = f and
                                    if fw.getEnclosingCallable().getName() = cs.getName()
                                    then result = getEntityConstructorParam(cs, fw)
                                    else result = getEntitySetterParam(c, f)
                                )
                            )
                        )
                    )
                )
            else (

                    (   (
                            not p.hasAnnotation("org.springframework.web.bind.annotation", "MatrixVariable")
                            and not p.hasAnnotation("org.springframework.web.bind.annotation", "PathVariable")
                            and not p.hasAnnotation("org.springframework.web.bind.annotation", "RequestAttribute")
                            and not p.hasAnnotation("org.springframework.web.bind.annotation", "RequestHeader")
                            and not p.hasAnnotation("org.springframework.web.bind.annotation", "CookieValue")
                        )
                        or not p.hasAnnotation()
                    )

                    and (result = paramParse(p.getType(), p.toString())
                        or (result = paramParse(p.getType().(ParameterizedType).getTypeArgument(0), p.toString())
                            and p.getType().(RefType).getAnAncestor().getSourceDeclaration().hasQualifiedName("org.springframework.http", "HttpEntity")
                        )
                        or exists(boolean bool | result = paramDateListParse(p.getType(), p.toString(), p.getAnAnnotation(), bool)
                            and bool = any(boolean inBool | not p.hasAnnotation("org.springframework.format.annotation", "DateTimeFormat") and inBool=true)
                        )
                        // 参数没有@RequestParam注解时调用paramParseNoRequestParam谓词获取请求参数
                        or exists(boolean bool | 
                            bool = any(boolean inBool | (not p.hasAnnotation("org.springframework.format.annotation", "DateTimeFormat") and inBool=true)
                                or (p.hasAnnotation("org.springframework.format.annotation", "DateTimeFormat") and inBool=false)
                            )
                            and bool = true
                            and result = paramParseNoRequestParam(p.getType())
                            )

                        )

                )
        )
    )
    )
    }

    /**
     * 3.1) 获取Entity类中的参数，1.获取构造方法中传参情况；2.存在setter方法
     * 该谓词从构造方法中获取参数
     * TODO：需要考虑下是否存在setter方法名和属性名不一致使用注解的情况
     * 文件上传未考虑
    */
    string getEntityConstructorParam(Constructor cs, FieldWrite fw){
        exists(Type t |
            ((fw.getRHS().(ExprParent).(Expr) = cs.getAParameter().getAnAccess() or
            fw.getRHS().(ExprParent).(Expr).getAChildExpr() = cs.getAParameter().getAnAccess() or
            fw.getRHS().(ExprParent).(Expr).getAChildExpr().getAChildExpr() = cs.getAParameter().getAnAccess() or
            fw.getRHS().(ExprParent).(Expr).getAChildExpr().getAChildExpr().getAChildExpr() = cs.getAParameter().getAnAccess())
            )
            and t = fw.getField().getType()
            // 处理字段类型为基本类型、String类型、文件上传并且考虑了数组、List泛型、Map泛型、Date情况(未考虑Set)

            and (result = paramParse(fw.getField().getType(), fw.getField().toString())
                or exists(boolean bool | result = paramDateListParse(fw.getField().getType(), fw.getField().toString(), fw.getField().getAnAnnotation(), bool)
                    and bool = any(boolean inBool | (not fw.getField().hasAnnotation("org.springframework.format.annotation", "DateTimeFormat") and inBool=true)
                    or (fw.getField().hasAnnotation("org.springframework.format.annotation", "DateTimeFormat") and inBool=false)
                )
                )
                or result = paramParseNoRequestParam(fw.getField().getType())
                )

        )
    }


    /**
     * 3.2) 从entity类中存在setter方法获取参数
    */
    string getEntitySetterParam(Class c, Field f){
        // c.hasName("UserDto") and f = c.getAField() and
        exists(SetterMethod sm, Type t |
            sm.isPublic() and c.getAMethod() = sm and
            sm.getName().toLowerCase().substring(3, sm.getName().length()) = f.getName().toLowerCase() and
            sm.getName().matches("set%")
            and c.getAField() = f
            and t = f.getType()
            // 处理字段类型为基本类型、String类型、文件上传并且考虑了数组、List泛型、Map泛型、Date情况(未考虑Set)

            and (result = paramParse(t, f.toString())
                or exists(boolean bool | result = paramDateListParse(t, f.toString(), f.getAnAnnotation(), bool)
                    and bool = any(boolean inBool | (not f.hasAnnotation("org.springframework.format.annotation", "DateTimeFormat") and inBool=true)
                        or (f.hasAnnotation("org.springframework.format.annotation", "DateTimeFormat") and inBool=false)
                    )
                )
                or result = paramParseNoRequestParam(t)
                )


        )
    }



    // 3-1) entity类不在源码时的情况
    string getNotFromSourceParam(Class c){
        exists(Method m, Method setM, Method getM, string fieldName, Type t, string paramValue, EntityParamTaintConfig ecfg, DataFlow::Node globalSource, DataFlow::Node globalSink |
            m.getParameter(0).getType() = c and not c.fromSource()
            and c.getAMethod() = setM and c.getAMethod() = getM
            and setM.getName().matches("set%")
            and getM.getName().matches("get%")
            and setM.getName().toLowerCase().substring(3, setM.getName().length()) = getM.getName().toLowerCase().substring(3, getM.getName().length())
            and setM.getAParamType() = getM.getReturnType()
            and fieldName = setM.getName().substring(3, 4).toLowerCase() + setM.getName().substring(4, setM.getName().length())

            and ecfg.hasFlow(globalSource, globalSink) 
            and globalSource.asParameter().getType() = globalSink.asExpr().(MethodAccess).getQualifier().getType()
            and globalSink.asExpr().(MethodAccess).getMethod() = getM
            // 根据参数数据类型赋值
            and t = getM.getReturnType()
            and stringParamValue(t) = paramValue
            and result = fieldName + "_" + t.getName() + "=" + paramValue
        )
    }



    /**
     * 4) 通过污点跟踪获取多层调用后开始从request对象中获取参数
    */
    string getFlowParam(Method m){

        m instanceof SpringRequestMappingMethod and

        exists(RequestParamTaintConfig cfg, DataFlow::Node source, DataFlow::Node sink|
            cfg.hasFlow(source, sink) 
            and source.asExpr().getEnclosingCallable() = m and not sink.asExpr().getEnclosingCallable() = m

            and
            (
                // 调用request对象的getParameter、getInputStream方法
                exists(MethodAccess ma | 
                    ma.getCaller() = sink.asExpr().getEnclosingCallable()
                    and (
                        (ma.getQualifier().getType().(RefType).getAnAncestor().getSourceDeclaration().hasQualifiedName("javax.servlet", "ServletRequest")
                            or ma.getQualifier().getType().(RefType).getAnAncestor().hasQualifiedName("org.springframework.web.context.request", "WebRequest")
                        )
                    and (ma.getMethod().hasName("getParameter")
                            and result = ma.getArgument(0).(CompileTimeConstantExpr).getStringValue() + "_String=test"
                        )
                    ) or (
                        ma.getQualifier().getType().(RefType).getAnAncestor().getSourceDeclaration().hasQualifiedName("javax.servlet", "ServletRequest")
                        and ma.getMethod().hasName("getInputStream")
                        and ma.getMethod().hasNoParameters() 
                        and result = "ParamIsRandom_InputStream=test"
                    )
                )

            or (
                sink.asExpr().getAChildExpr().getType().hasName("MultipartHttpServletRequest")
                and result = "ParamIsRandom_Multipart=filename.jpg"
                )
            // 调用request.getParts()方法进行文件上传
            or exists(MethodAccess ma, Interface interface |
                interface.getAnAncestor().hasQualifiedName("javax.servlet.http", "HttpServletRequest")
                and ma.getEnclosingCallable() = sink.getEnclosingCallable()
                and ma.getMethod().hasName("getParts")
                and ma.getMethod().hasNoParameters()

                and ma.getMethod().overridesOrInstantiates*(interface.getAMethod())
                and result = "ParamIsRandom_Multipart=filename.jpg"
                )
            )
        )
    }





    // 需要考虑无参数和参数为Model等情况
    string getParam(Method m){
        exists(string param | 
            param = "?" +
            concat(string i| i in [getRequestParamModelAttribute(m)] | i, "&")
            + "&" + concat(string i| i in [getFuncParam(m)] | i, "&")
            + "&" + concat(string i| i in [getFuncBlockParam(m)] | i, "&")
            + "&" + concat(string i| i in [getFlowParam(m)] | i, "&")
            and result = param.regexpReplaceAll("\\?&&&$", "").replaceAll("?&&", "?").replaceAll("?&", "?").replaceAll("&&", "").regexpReplaceAll("&$", "")
        )

    }


    string getPath(Method m) {
        exists(MappingMethod mm | 
            result = mm.getMappedPath() and mm = m
            )
    }

    string getMethodType(Method m) {
        exists(RequestMethodType mm | 
            mm = m and result = concat(string i| i in [mm.getMethodType()] | i, "/")
        )
    }

    string getContentType(Method m) {
        exists(RequestContentType mm | 
            mm = m and result = concat(string i| i in [mm.getContentType()] | i, "&")
            )
    }

    // 还需要对method进行过滤，比如upload的工具类可能会被认为mapping的方法
    string getUrl(Method method){
        exists(SpringRequestMappingMethod m | 
            method = m and
            result = getMethodType(m) + " " + getPath(m) + getParam(m) + " " + getContentType(m)
            )
    }



}
