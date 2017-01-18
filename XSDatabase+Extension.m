//
//  XSDatabase+Extension.m
//  XSDatabase
//
//  Created by xisi on 2017/1/15.
//  Copyright © 2017年 xisi. All rights reserved.
//

#import "XSDatabase+Extension.h"

@implementation XSDatabase (Extension)

#pragma mark - 查询
//_______________________________________________________________________________________________________________

- (NSMutableArray *)databaseList {
    NSString *sqlString = [NSString stringWithFormat:@"pragma database_list"];
    NSMutableArray *array = [self selectSQL:sqlString];
    return array;
}

/*!
 当前所有连接的数据库中的所有表
 */
- (NSMutableArray *)tableList {
    NSMutableArray *allTablesArray = [NSMutableArray new];
    NSMutableArray *dbArray = [self databaseList];
    for (NSDictionary *dbDict in dbArray) {
        NSString *dbName = dbDict[@"name"];           //  当前数据库名
        /*
         select * from %@.sqlite_master where type in ('table','view') and name not like 'sqlite_%%' union \
         select * from %@.sqlite_temp_master where type in ('table','view') and name not like 'sqlite_%%'
         */
        NSString *sqlString = [NSString stringWithFormat:
                               @"select * from %@.sqlite_master where type in ('table','view') and name not like 'sqlite_%%'", dbName];
        NSMutableArray *tbArray = [self selectSQL:sqlString];
        for (int i = 0; i < tbArray.count; i++) {
            NSMutableDictionary *tbDict = tbArray[i];
            NSString *tbName = [NSString stringWithFormat:@"%@.%@", dbName, tbDict[@"name"]];
            [tbDict setObject:tbName forKey:@"name"];
            [allTablesArray addObject:tbDict];
        }
    }
    return allTablesArray;
}

/*!
 格式：PRAGMA database.table_info(table-name);
 '.'号分割数据库、表
 */
- (NSMutableArray *)tableInfo:(NSString *)dbTable {
    NSString *db, *tb;
    NSArray *arr = [dbTable componentsSeparatedByString:@"."];
    if (arr.count == 2) {
        db = [NSString stringWithFormat:@"%@.", arr.firstObject];
        tb = arr.lastObject;
    } else if (arr.count == 1) {
        db = @"";
        tb = arr.lastObject;
    } else {
//        SQLiteLog(@"表格式错误!");
    }
    NSString *sqlString = [NSString stringWithFormat:@"pragma %@table_info(%@)", db, tb];
    NSMutableArray *array = [self selectSQL:sqlString];
    return array;
}

- (BOOL)hasTable:(NSString *)dbTable {
    NSArray *array = [self tableList];
    for (NSDictionary *dict in array) {
        //  name、tbl_name：index和trigger依附表而存在
        if ([dbTable isEqualToString:dict[@"name"]]) {
            return YES;
        }
    }
    return NO;
}


#pragma mark - 删除
//_______________________________________________________________________________________________________________

- (BOOL)deleteAllRowsFromTable:(NSString *)dbTable {
    NSString *sql = [NSString stringWithFormat:@"delete from %@", dbTable];
    BOOL isSuccess = [self executeSQL:sql];
    return isSuccess;
}

- (BOOL)deleteTable:(NSString *)dbTable {
    NSArray *array = [self tableList];
    for (NSDictionary *dict in array) {
        if ([dbTable isEqualToString:dict[@"name"]]) {
            NSString *sql = [NSString stringWithFormat:@"drop %@ if exists %@", dict[@"type"], dict[@"name"]];
            BOOL isSuccess = [self executeSQL:sql];
            return isSuccess;
        }
    }
    return NO;
}


- (BOOL)deleteAll {
    NSArray *array = [self tableList];
    NSMutableString *sqls = [NSMutableString new];
    for (NSDictionary *dict in array) {
        NSString *sql = [NSString stringWithFormat:@"drop %@ if exists %@", dict[@"type"], dict[@"name"]];
        [sqls appendFormat:@"%@; ", sql];
    }
    BOOL isSuccess = [self executeSQL:sqls];
    return isSuccess;
}


#pragma mark -  其他
//_______________________________________________________________________________________________________________

- (NSString *)SQLReplaceForTable:(NSString *)dbTable dict:(NSDictionary *)dict {
    NSMutableArray *sharedKeys = [NSMutableArray new];
    
    NSMutableArray *columnDict = [self tableInfo:dbTable];
    NSMutableArray *columnNames = [NSMutableArray new];
    for (NSDictionary *tableInfoDict in columnDict) {
        [columnNames addObject:tableInfoDict[@"name"]];
    }
    
    //  查找共同的键
    for (NSString *key in dict.allKeys) {
        if ([columnNames containsObject:key]) {
            [sharedKeys addObject:key];
        }
    }
    
    if (sharedKeys.count == 0) {
        return nil;
    }
    
    char *sql = NULL;
    sql = sqlite3_mprintf("replace into %s (", dbTable.UTF8String);
    //  构建字段名
    for (int i = 0; i < sharedKeys.count; i++) {
        NSString *aKey = sharedKeys[i];
        const char *sqlKey = aKey.UTF8String;
        char *str = i < sharedKeys.count - 1  ?  ", "  :  ") values (";
        sql = sqlite3_mprintf("%s%s%s", sql, sqlKey, str);
    }
    
    //  对应字段名的冒号标识
    for (int i = 0; i < sharedKeys.count; i++) {
        NSString *aKey = [NSString stringWithFormat:@":%@", sharedKeys[i]];
        const char *sqlKey = aKey.UTF8String;
        char *str = i < sharedKeys.count - 1  ?  ", "  :  ")";
        sql = sqlite3_mprintf("%s%s%s", sql, sqlKey, str);
    }
    
    return [NSString stringWithUTF8String:sql];
}

@end
