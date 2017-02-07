//
//  XSDatabaseModel.m
//  XSDatabase
//
//  Created by xisi on 2017/1/17.
//  Copyright © 2017年 xisi. All rights reserved.
//

#import "XSDatabaseModel.h"
#import <objc/runtime.h>

@implementation XSDatabaseModel

//! 查询
+ (NSArray<XSDatabaseModel *> *)objectsWhere:(NSString *)whereSql {
    Class cls = [self class];
    NSString *sql = [NSString stringWithFormat:@"select * from %@ %@;", [self class], (whereSql.length ? whereSql : @"")];
    
    unsigned int count;
    objc_property_t *props = class_copyPropertyList(cls, &count);
    NSDictionary *dict = [self tableColumnNameAndColumnIDDict];
    
    XSDatabase *currentDB = [XSDatabase currentDatabase];
    NSMutableArray *array = [NSMutableArray new];
    [currentDB selectSQL:sql eachStmt:^(int index, sqlite3_stmt *stmt) {
        id object = [cls new];
        for (int i = 0; i < count; i++) {
            objc_property_t prop = props[i];
            const char *pName = property_getName(prop);
            const char *pType = property_copyAttributeValue(prop, "T");
            NSString *key = [NSString stringWithFormat:@"%s", pName];
            if (dict[key] == nil) {     //  该属性在表中不存在
                free((void *)pType);
                continue;
            }
            int iCol = [dict[key] intValue];            //  iCol >= 0
            id value = nil;
            
            //---------------- NSNumber基础数据类型 ----------------
            if (pType[0] == @encode(char)[0] || pType[0] == @encode(unsigned char)[0] ||
                pType[0] == @encode(short)[0] || pType[0] == @encode(unsigned short)[0] ||
                pType[0] == @encode(int)[0] || pType[0] == @encode(unsigned int)[0] ||
                pType[0] == @encode(BOOL)[0]) {
                int num = sqlite3_column_int(stmt, iCol);
                value = @(num);
            } else if (pType[0] == @encode(long)[0] || pType[0] == @encode(unsigned long)[0] ||
                       pType[0] == @encode(long long)[0] || pType[0] == @encode(unsigned long long)[0] ||
                       pType[0] == @encode(NSInteger)[0] || pType[0] == @encode(NSUInteger)[0]) {
                sqlite3_int64 num = sqlite3_column_int64(stmt, iCol);
                value = @(num);
            } else if (pType[0] == @encode(float)[0] || pType[0] == @encode(double)[0]) {
                double num = sqlite3_column_double(stmt, iCol);
                value = @(num);
            }
            //---------------- NSNumber数据类型 ----------------
            else if (strcmp(pType, "@\"NSNumber\"") == 0) {
                const unsigned char *str = sqlite3_column_text(stmt, iCol);
                if (str == NULL) {
                    value = nil;
                } else {
                    NSString *numberStr = [NSString stringWithUTF8String:(const char *)str];
                    value = [[self defaultNumberFormatter] numberFromString:numberStr];
                }
            }
            //---------------- NSString数据类型 ----------------
            else if (strcmp(pType, "@\"NSString\"") == 0) {
                const unsigned char *str = sqlite3_column_text(stmt, iCol);
                if (str == NULL) {
                    value = nil;
                } else {
                    value = [NSString stringWithUTF8String:(const char *)str];
                }
            }
            //---------------- NSDate数据类型 ----------------
            else if (strcmp(pType, "@\"NSDate\"") == 0) {
                const unsigned char *str = sqlite3_column_text(stmt, iCol);
                if (str == NULL) {
                    value = nil;
                } else {
                    NSString *dateString = [NSString stringWithUTF8String:(const char *)str];
                    NSDate *date = [[self defaultDateFormatter] dateFromString:dateString];
                    value = date;
                }
            }
            //---------------- 其他 ----------------
            else {
                const void *bytes = sqlite3_column_blob(stmt, i);
                int len = sqlite3_column_bytes(stmt, i);
                NSData *data = [NSData dataWithBytes:bytes length:len];
                value = [NSKeyedUnarchiver unarchiveObjectWithData:data];
            }
            if (value) {
                [object setValue:value forKey:key];
            }
            free((void *)pType);
        }
        [array addObject:object];
    }];
    free(props);
    return array;
}

+ (BOOL)deleteAll {
    NSString *sql = [NSString stringWithFormat:@"delete from %@;", [self class]];
    return [[XSDatabase currentDatabase] executeSQL:sql];
}

- (BOOL)delete {
    NSString *primaryKey = [[self class] primaryKey];
    NSString *sql = [NSString stringWithFormat:@"delete from %@ where %@=%@;", [self class], primaryKey, [self valueForKey:primaryKey]];
    return [[XSDatabase currentDatabase] executeSQL:sql];
}

- (BOOL)insert {
    static NSString *sql;           //  语句内容固定
    if (sql == nil) {
        sql = [self insertSql];
    }
    return [self updateWithSql:sql];
}

- (BOOL)insertOrReplace {
    static NSString *sql;           //  语句内容固定
    if (sql == nil) {
        sql = [self insertSql];
        sql = [sql stringByReplacingOccurrencesOfString:@"insert into" withString:@"replace into"];
    }
    return [self updateWithSql:sql];
}

//  构建插入sql
- (NSString *)insertSql {
    NSArray *array = [[self class] propertiesInTable];
    if (array.count == 0) {
        return nil;
    }
    
    NSMutableString *mStr = [NSMutableString new];
    [mStr appendFormat:@"insert into %@ (", self.class];
    
    [mStr appendFormat:@"%@", array[0]];
    for (int i = 1; i < array.count; i++) {
        [mStr appendFormat:@", %@", array[i]];
    }
    
    [mStr appendFormat:@") values ("];
    [mStr appendFormat:@":%@", array[0]];
    for (int i = 1; i < array.count; i++) {
        [mStr appendFormat:@", :%@", array[i]];
    }
    
    [mStr appendFormat:@");"];
    return mStr;
}

- (BOOL)update {
    NSString *sql = [self updateSql];       //  语句内容不固定
    return [self updateWithSql:sql];
    return YES;
}

//  构建更新sql
- (NSString *)updateSql {
    NSArray *array = [[self class] propertiesInTable];
    if (array.count == 0) {
        return nil;
    }
    
    NSMutableString *mStr = [NSMutableString new];
    [mStr appendFormat:@"update %@ set ", self.class];
    
    [mStr appendFormat:@"%@=:%@", array[0], array[0]];
    for (int i = 1; i < array.count; i++) {
        [mStr appendFormat:@", %@=:%@", array[i], array[i]];
    }
    
    NSString *primaryKey = [[self class] primaryKey];
    [mStr appendFormat:@" where %@=%@;", primaryKey, [self valueForKey:primaryKey]];
    return mStr;
}

/*!
    根据主键更新数据
 
    insert、insertOrReplace、update，都走这个接口
 */
- (BOOL)updateWithSql:(NSString *)sql {
    Class cls = [self class];
    
    unsigned int count;
    objc_property_t *props = class_copyPropertyList(cls, &count);
    NSDictionary *dict = [[self class] tableColumnNameAndColumnIDDict];
    
    XSDatabase *currentDB = [XSDatabase currentDatabase];
    BOOL result = [currentDB updateSQL:sql count:1 eachStmt:^(int index, sqlite3_stmt *stmt) {
        for (int i = 0; i < count; i++) {
            objc_property_t prop = props[i];
            const char *pName = property_getName(prop);
            const char *pType = property_copyAttributeValue(prop, "T");
            NSString *key = [NSString stringWithFormat:@"%s", pName];
            if (dict[key] == nil) {     //  该属性在表中不存在
                free((void *)pType);
                continue;
            }
            
            NSString *colon = [NSString stringWithFormat:@":%@", key];
            int idx = sqlite3_bind_parameter_index(stmt, colon.UTF8String);             //  寻找该参数在SQL语句中的位置
            if (idx == 0) {
                free((void *)pType);
                continue;
            }
            id value = [self valueForKey:key];
            
            //---------------- NSNumber基础数据类型 ----------------
            if (pType[0] == @encode(char)[0]) {
                sqlite3_bind_int(stmt, idx, [value charValue]);
            } else if (pType[0] == @encode(unsigned char)[0]) {
                sqlite3_bind_int(stmt, idx, [value unsignedCharValue]);
            } else if (pType[0] == @encode(short)[0]) {
                sqlite3_bind_int(stmt, idx, [value shortValue]);
            } else if (pType[0] == @encode(unsigned short)[0]) {
                sqlite3_bind_int(stmt, idx, [value unsignedShortValue]);
            } else if (pType[0] == @encode(int)[0]) {
                sqlite3_bind_int(stmt, idx, [value intValue]);
            } else if (pType[0] == @encode(unsigned int)[0]) {
                sqlite3_bind_int64(stmt, idx, (long long)[value unsignedIntValue]);
            } else if (pType[0] == @encode(long)[0]) {
                sqlite3_bind_int64(stmt, idx, [value longValue]);
            } else if (pType[0] == @encode(unsigned long)[0]) {
                sqlite3_bind_int64(stmt, idx, (long long)[value unsignedLongValue]);
            } else if (pType[0] == @encode(long long)[0]) {
                sqlite3_bind_int64(stmt, idx, [value longLongValue]);
            } else if (pType[0] == @encode(unsigned long long)[0]) {
                sqlite3_bind_int64(stmt, idx, (long long)[value unsignedLongLongValue]);
            } else if (pType[0] == @encode(float)[0]) {
                sqlite3_bind_double(stmt, idx, [value floatValue]);
            } else if (pType[0] == @encode(double)[0]) {
                sqlite3_bind_double(stmt, idx, [value doubleValue]);
            } else if (pType[0] == @encode(BOOL)[0]) {
                sqlite3_bind_int(stmt, idx, [value boolValue]);
            } else if (pType[0] == @encode(NSInteger)[0]) {
                sqlite3_bind_int64(stmt, idx, [value longLongValue]);
            } else if (pType[0] == @encode(NSUInteger)[0]) {
                sqlite3_bind_int64(stmt, idx, [value unsignedLongLongValue]);
            }
            //---------------- NSNumber数据类型 ----------------
            else if (strcmp(pType, "@\"NSNumber\"") == 0) {
                NSString *numberStr = [[[self class] defaultNumberFormatter] stringFromNumber:value];
                sqlite3_bind_text(stmt, idx, numberStr.UTF8String, -1, NULL);
            }
            //---------------- NSString数据类型 ----------------
            else if (strcmp(pType, "@\"NSString\"") == 0) {
                sqlite3_bind_text(stmt, idx, [value UTF8String], -1, NULL);
            }
            //---------------- NSDate数据类型 ----------------
            else if (strcmp(pType, "@\"NSDate\"") == 0) {
                NSString *str = [[[self class] defaultDateFormatter] stringFromDate:value];
                sqlite3_bind_text(stmt, idx, [str UTF8String], -1, NULL);
            }
            //---------------- 其他 ----------------
            else {
                NSData *data = [NSKeyedArchiver archivedDataWithRootObject:value];
                const void *bytes = data.bytes;
                NSUInteger len = data.length;
                sqlite3_bind_blob(stmt, idx, bytes, (int)len, NULL);
            }
            free((void *)pType);
        }
    }];
    free(props);
    return result;
}

#pragma mark -  非接口
//_______________________________________________________________________________________________________________

//! 得到表的信息
+ (NSArray *)tableInfo {
    Class cls = [self class];
    NSString *className = NSStringFromClass(cls);
    
    XSDatabase *currentDB = [XSDatabase currentDatabase];
    NSString *sql = [NSString stringWithFormat:@"pragma table_info(%@)", className];
    NSArray *array = [currentDB selectSQL:sql];
    return array;
}

/*!
 在查询时，需要获取属性在表中对应的列位置
 
 name ---- cid   (key - value)
 */
+ (NSDictionary *)tableColumnNameAndColumnIDDict {
    static NSMutableDictionary *mDict = nil;
    if (mDict == nil) {
        NSArray *array = [self tableInfo];
        mDict = [NSMutableDictionary new];
        for (int i = 0; i < array.count; i++) {
            NSDictionary *dict = array[i];
            [mDict setObject:dict[@"cid"] forKey:dict[@"name"]];
        }
    }
    return mDict;
}

//! 找到表中存在的property属性，用于构建sql语句
+ (NSArray *)propertiesInTable {
    static NSMutableArray *array = nil;
    if (array == nil) {
        array = [NSMutableArray new];
        Class cls = [self class];
        unsigned int count;
        objc_property_t *props = class_copyPropertyList(cls, &count);
        NSDictionary *dict = [self tableColumnNameAndColumnIDDict];
        
        for (int i = 0; i < count; i++) {
            objc_property_t prop = props[i];
            const char *pName = property_getName(prop);
            NSString *key = [NSString stringWithFormat:@"%s", pName];
            if (dict[key] != nil) {     //  该属性在表中不存在
                [array addObject:key];
            }
        }
        free(props);
    }
    return array;
}

//! 获取表的主键，用于update
+ (NSString *)primaryKey {
    static NSString *primaryKey = nil;
    if (primaryKey == nil) {
        NSArray *array = [self tableInfo];
        for (int i = 0; i < array.count; i++) {
            NSDictionary *dict = array[i];
            if ([dict[@"pk"] intValue] == 1) {
                primaryKey = dict[@"name"];
                break;
            }
        }
    }
    NSAssert1(primaryKey.length, @"表 %@ 必须得有主键才能使用本方法", [self class]);
    return primaryKey;
}

+ (NSDateFormatter *)defaultDateFormatter {
    static NSDateFormatter *dateFormatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dateFormatter = [NSDateFormatter new];
    });
    //  "yyyy-MM-dd HH:mm:ss SSS"
    dateFormatter.dateFormat = @"yyyy-MM-dd HH:mm:ss SSS";
    return dateFormatter;
}

+ (NSNumberFormatter *)defaultNumberFormatter {
    static NSNumberFormatter *numberFormatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        numberFormatter = [NSNumberFormatter new];
        numberFormatter.numberStyle = NSNumberFormatterDecimalStyle;
        numberFormatter.usesGroupingSeparator = NO;
    });
    return numberFormatter;
}

@end
