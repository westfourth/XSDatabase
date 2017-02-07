//
//  XSDatabase+Base.m
//  XSDatabase
//
//  Created by xisi on 2017/1/15.
//  Copyright © 2017年 xisi. All rights reserved.
//

#import "XSDatabase+Base.h"
#import <objc/objc-sync.h>

@implementation XSDatabase (Base)

static XSDatabase *StaticDatabase;

- (int)userVersion {
    NSString *sql = [NSString stringWithFormat:@"pragma user_version"];
    NSMutableArray *array = [self selectSQL:sql];
    return [array.firstObject[@"user_version"] intValue];
}

- (void)setUserVersion:(int)userVersion {
    NSString *sql = [NSString stringWithFormat:@"pragma user_version=%d", userVersion];
    [self executeSQL:sql];
}


#pragma mark -  多用户环境
//_______________________________________________________________________________________________________________

+ (XSDatabase *)defaultDatabase {
    XSDatabase *database = [self databaseWithID:@"Database"];
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [database openDB];
    });
    return database;
}

+ (XSDatabase *)currentDatabase {
    return StaticDatabase ? StaticDatabase : [self defaultDatabase];
}

+ (void)setCurrentDatabase:(XSDatabase *)database {
    objc_sync_enter(self);
    if (!database.isOpen) {
        [database openDB];
    }
    StaticDatabase = database;
    objc_sync_exit(self);
}

+ (XSDatabase *)databaseWithID:(NSString *)ID {
    static NSMutableDictionary *dict;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dict = [NSMutableDictionary new];
    });
    
    objc_sync_enter(dict);
    XSDatabase *database = dict[ID];
    if (database == nil) {
        database = [XSDatabase new];
        dict[ID] = database;
        NSString *cacheDir = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject;
        NSString *fileName = [NSString stringWithFormat:@"%@.db", ID];
        database.filePath = [cacheDir stringByAppendingPathComponent:fileName];
    }
    objc_sync_exit(dict);
    return database;
}


#pragma mark -  基于字典、数组的操作
//_______________________________________________________________________________________________________________

- (NSMutableArray *)selectSQL:(NSString *)sqlString {
    NSMutableArray *array = [NSMutableArray new];
    [self selectSQL:sqlString eachStmt:^(int index, sqlite3_stmt *stmt) {
        NSMutableDictionary *dict = [NSMutableDictionary new];
        int columnCount = sqlite3_column_count(stmt);
        for (int i = 0; i < columnCount; i++) {                         //  遍历行的列
            id object;
            const char *name = sqlite3_column_name(stmt, i);
            NSString *nameStr = [NSString stringWithUTF8String:name];
            /*
             实际的类型，可能与申明的类型不同
             例如：该类型为double，但实际可能为text。（即小范围的数据内存储的是大范围的数据）
             */
            int columnType = sqlite3_column_type(stmt, i);
            switch (columnType) {
                case SQLITE_INTEGER: {          //  INT64_MAX   (9 * 10ˆ18次方)
                    sqlite3_int64 num = sqlite3_column_int64(stmt, i);
                    NSNumber *number = [NSNumber numberWithLongLong:num];
                    object = number;
                }
                    break;
                case SQLITE_FLOAT: {            //  FLT_MAX     (3 * 10ˆ38次方)
                    double num = sqlite3_column_double(stmt, i);
                    NSNumber *number = [NSNumber numberWithDouble:num];
                    object = number;
                }
                    break;
                case SQLITE_TEXT: {
                    const unsigned char *str = sqlite3_column_text(stmt, i);
                    NSString *string = [NSString stringWithUTF8String:(const char *)str];       //  注意：强制转换（完全兼容）
                    object = string;
                }
                    break;
                case SQLITE_BLOB: {
                    const void *bytes = sqlite3_column_blob(stmt, i);
                    int len = sqlite3_column_bytes(stmt, i);
                    NSData *data = [NSData dataWithBytes:bytes length:len];
                    object = [NSKeyedUnarchiver unarchiveObjectWithData:data];
                }
                    break;
                case SQLITE_NULL: {         //  这一步再细分
                    const char *decltype = sqlite3_column_decltype(stmt, i);
                    if (decltype == NULL) {
                        decltype = "UNKNOWN";
                    }
                    if (strcasestr(decltype, "INT") != NULL) {               //  整形
                        object = [NSNumber numberWithLongLong:0];
                    } else if (strcasestr(decltype, "REAL") != NULL ||
                               strcasestr(decltype, "FLOA") != NULL ||
                               strcasestr(decltype, "DOUB") != NULL) {      //  浮点型
                        object = [NSNumber numberWithDouble:0];
                    } else if (strcasestr(decltype, "CHAR") != NULL ||
                               strcasestr(decltype, "CLOB") != NULL ||
                               strcasestr(decltype, "TEXT") != NULL) {      //  字符串
                        object = @"";
                    } else if (strcasestr(decltype, "BLOB") != NULL) {      //  块
                        object = [NSData new];
                    } else {                                                                        //  其他
                        //  申明类型不确定时，比如NUMERIC、DECIMAL(10,5)、BOOLEAN、DATE、DATETIME
                        object = [NSNull null];
                    }
                }
                    break;
                default:        //  实际上不会执行这一步
                    break;
            }
            [dict setObject:object forKey:nameStr];
        }
        [array addObject:dict];
    }];
    return array;
}

- (BOOL)updateSQL:(NSString *)sqlString dict:(NSDictionary *)dict {
    return [self updateSQL:sqlString count:1 eachStmt:^(int index, sqlite3_stmt *stmt) {
        //  如果sqlite3_bind_parameter_index返回值为0的话，则sqlite3_bind_xxx将失败，但不影响程序
        for (int i = 0; i < dict.count; i++) {
            NSString *key = dict.allKeys[i];
            NSString *colon = [NSString stringWithFormat:@":%@", key];
            int idx = sqlite3_bind_parameter_index(stmt, colon.UTF8String);             //  寻找该参数在SQL语句中的位置
            if (idx > 0) {          //  查找到了该字段
                id object = dict.allValues[i];
                if ([object isKindOfClass:[NSNumber class]]) {              //  如果为NSNumber
                    if (strcmp([object objCType], @encode(char)) == 0) {
                        sqlite3_bind_int(stmt, idx, [object charValue]);
                    }
                    else if (strcmp([object objCType], @encode(unsigned char)) == 0) {
                        sqlite3_bind_int(stmt, idx, [object unsignedCharValue]);
                    }
                    else if (strcmp([object objCType], @encode(short)) == 0) {
                        sqlite3_bind_int(stmt, idx, [object shortValue]);
                    }
                    else if (strcmp([object objCType], @encode(unsigned short)) == 0) {
                        sqlite3_bind_int(stmt, idx, [object unsignedShortValue]);
                    }
                    else if (strcmp([object objCType], @encode(int)) == 0) {
                        sqlite3_bind_int(stmt, idx, [object intValue]);
                    }
                    else if (strcmp([object objCType], @encode(unsigned int)) == 0) {
                        sqlite3_bind_int64(stmt, idx, (long long)[object unsignedIntValue]);
                    }
                    else if (strcmp([object objCType], @encode(long)) == 0) {
                        sqlite3_bind_int64(stmt, idx, [object longValue]);
                    }
                    else if (strcmp([object objCType], @encode(unsigned long)) == 0) {
                        sqlite3_bind_int64(stmt, idx, (long long)[object unsignedLongValue]);
                    }
                    else if (strcmp([object objCType], @encode(long long)) == 0) {
                        sqlite3_bind_int64(stmt, idx, [object longLongValue]);
                    }
                    else if (strcmp([object objCType], @encode(unsigned long long)) == 0) {
                        sqlite3_bind_int64(stmt, idx, (long long)[object unsignedLongLongValue]);
                    }
                    else if (strcmp([object objCType], @encode(float)) == 0) {
                        sqlite3_bind_double(stmt, idx, [object floatValue]);
                    }
                    else if (strcmp([object objCType], @encode(double)) == 0) {
                        sqlite3_bind_double(stmt, idx, [object doubleValue]);
                    }
                    else if (strcmp([object objCType], @encode(BOOL)) == 0) {
                        sqlite3_bind_int(stmt, idx, [object boolValue]);
                    }
                    else if (strcmp([object objCType], @encode(NSInteger)) == 0) {
                        sqlite3_bind_int64(stmt, idx, [object longLongValue]);
                    }
                    else if (strcmp([object objCType], @encode(NSUInteger)) == 0) {
                        sqlite3_bind_int64(stmt, idx, [object unsignedLongLongValue]);
                    }
                } else if ([object isKindOfClass:[NSString class]]) {       //  如果为NSString
                    sqlite3_bind_text(stmt, idx, [object UTF8String], -1, NULL);
                } else if ([object isKindOfClass:[NSNull class]]) {         //  如果为NSNull
                    sqlite3_bind_null(stmt, idx);
                } else {                                                    //  其他
                    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:object];
                    const void *bytes = data.bytes;
                    NSUInteger len = data.length;
                    sqlite3_bind_blob(stmt, idx, bytes, (int)len, NULL);
                }
            }
        }
    }];
}


#pragma mark -  分离附加数据库文件
//_______________________________________________________________________________________________________________

- (BOOL)attachDBFile:(NSString *)dbFile asDBName:(NSString *)dbName {
    NSString *sql = [NSString stringWithFormat:@"attach '%@' as %@", dbFile, dbName];
    return [self executeSQL:sql];
}


- (BOOL)detachDBName:(NSString *)dbName {
    NSString *sql = [NSString stringWithFormat:@"detach %@", dbName];
    return [self executeSQL:sql];
}


#pragma mark - 事务支持
//_______________________________________________________________________________________________________________

- (BOOL)isAutoCommit {
    return sqlite3_get_autocommit(_db);
}

- (BOOL)beginTransaction {
    /*
     设置多线程中多对象并发事务，指定锁行为。
     0 - deferred（其他可读写，默认）
     1 - immediate（其他只读），其他数据库连接不可写入，也不可开启IMMEDIATE、EXCLUSIVE事务
     2 - exclusive（不可读写），其他数据库连接只能读取数据
     */
    sqlite3_mutex_enter(_transaction_mutex);
    BOOL success = [self executeSQL:@"begin"];
    return success;
}


- (BOOL)commitTransaction {
    BOOL success = [self executeSQL:@"commit"];
    sqlite3_mutex_leave(_transaction_mutex);
    return success;
}


- (BOOL)rollbackTransaction {
    BOOL success = [self executeSQL:@"rollback"];
    sqlite3_mutex_leave(_transaction_mutex);
    return success;
}


#pragma mark -  事务断点支持
//_______________________________________________________________________________________________________________

- (BOOL)savepoint:(NSString *)savepoint {
    NSString *sql = [NSString stringWithFormat:@"savepoint %@", savepoint];
    return [self executeSQL:sql];
}


- (BOOL)releaseSavepoint:(NSString *)savepoint {
    NSString *sql = [NSString stringWithFormat:@"release %@", savepoint];
    return [self executeSQL:sql];
}


- (BOOL)rollbackToSavepoint:(NSString *)savepoint {
    NSString *sql = [NSString stringWithFormat:@"rollback to %@", savepoint];
    return [self executeSQL:sql];
}


#pragma mark -  内置功能
//_______________________________________________________________________________________________________________

+ (BOOL)isCompleteSQL:(NSString *)sql {
    return sqlite3_complete(sql.UTF8String);
}

+ (int)memoryUsed {
    return (int)sqlite3_memory_used();
}

+ (int)memoryHighWater {
    return (int)sqlite3_memory_highwater(0);
}

- (void)interrupt {
    sqlite3_interrupt(_db);
}

- (int)lastInsertRowID {
    return (int)sqlite3_last_insert_rowid(_db);
}

- (int)changes {
    return sqlite3_changes(_db);
}

@end
