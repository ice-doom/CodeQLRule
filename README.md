# CodeQLRule
个人使用CodeQL编写的一些规则

## ApplicationRoutes

查询应用的路由信息

### SpringMVC

![SpringMVC](https://user-images.githubusercontent.com/25363717/160372489-33bd5928-9d4a-4e6d-a42f-74aec3e24e0d.png)

#### TODO

- [ ] python工具脚本完成：codeql查询结果再进行处理包括本地保存处理后的内容、自动发送请求至目标
- [ ] `Mapping`注解中使用`headers`表示需要带上的header头
- [ ] `GetMapping`注解中使用`produces`表示Context-Type类型，可能需要添加该项
- [ ] `Mapping`注解中设置了`params`表示需要带上的参数名，可以没有值
- [ ] Date类型目前只考虑了`@DateTimeFormat(iso=ISO.DATE)`
- [ ] Entity类中实现`PathVariable`
    RESTful风格，在Entity类中绑定参数，
    ```java
    @GetMapping("dataBinding/{foo}/{fruit}")
    public String dataBinding(@Valid JavaBean javaBean, Model model){}
    ```
- [ ] RESTful风格，使用`PathVariable`等注解，目前可能存在问题，而且导致代码量较大，后期可能去除该项，直接取注解等信息然后通过Python额外处理
- [ ] 参数存在`@Valid`注解对参数进行校验，将该类中在字段的注解定义了规范
- [ ] 参数类型为`Map`则需要找到`Map.get`获取参数值的地方获取参数名（优先处理完成该项）
- [ ] setter和构造函数传入参数和字段名不一致情况，是否需要考虑
- [ ] 当接口的方法中使用`Mapping`等注解配置好，其实现类中再重写相应的方法，这种情况下实现类没有任何注解则需要额外考虑这种情况
- [ ] 是否可以适用Struts2





