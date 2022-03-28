## TODO

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
- [ ] 是否可以适用Struts2
