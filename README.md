# XSDatabase

面向对象的数据库

## 为什么重复造轮子

数据的增、删、改、查直接面向对象，牺牲一点点运行效率，提升开发效率、可读性、维护性。

## 使用

### 1. 建表

为了较少复杂度，增加自由度，不直接在模型上建表，而是写sql语句建表。

- **sql示例代码**

``` sql
--文件：Test.sql
create table TestModel(
    msgID       INT PRIMARY KEY,    --消息ID
    content     TEXT,               --消息内容
    timestamp   INT                 --时间戳
);
```

- **Objective-C示例代码**

``` objc
- (void)create {
    NSString *path = [[NSBundle mainBundle] pathForResource:@"Test" ofType:@"sql"];
    NSError *error = nil;
    NSString *sql = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
    
    XSDatabase *db = [XSDatabase defaultDatabase];
    [db executeSQL:sql];
}
```

### 2. 插入

批量插入的时候注意开启事务

``` objc
- (void)insert {
    XSDatabase *db = [XSDatabase defaultDatabase];
    [db beginTransaction];
    for (NSUInteger i = 0; i < 10000; i++) {
        TestModel *m = [TestModel new];
        m.msgID = i;
        m.content = [NSString stringWithFormat:@"第%ld个内容", i];
        m.timestamp = [[NSDate date] timeIntervalSince1970] + i;
        [m insert];
    }
    [db commitTransaction];
}
```

### 3. 查询

``` objc
- (void)query {
    NSArray *models = [TestModel objectsWhere:nil];
}
```

### 4. 条件查询

``` objc
- (void)query {
    NSArray *models = [TestModel objectsWhere:@"where msgID=99"];
}
```

### 5. 更新

``` objc
- (void)update {
    TestModel *m = [TestModel objectsWhere:@"where msgID=99"].firstObject;
    m.content = @"更新测试";
    [m update];
}
```

### 6. 删除

``` objc
- (void)delete {
    TestModel *m = [TestModel objectsWhere:@"where msgID=99"].firstObject;
    [m delete];
}
```
