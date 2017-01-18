//
//  Database.m
//  DataBaseTest
//
//  Created by xisi on 13-12-10.
//  Copyright (c) 2013年 77. All rights reserved.
//

#import "XSDatabase.h"

@implementation XSDatabase

#pragma mark -  打开关闭数据库
//_______________________________________________________________________________________________________________

- (BOOL)isOpen {
    const char *s = sqlite3_db_filename(_db, "main");
    return s != NULL;
}

- (void)openDB {
    if (self.filePath.length == 0) {
        self.filePath = @":memory:";
    }
    /*
     打开标记：读写、不存在创建、串行模式。
     串行模式为线程安全；单线程模式、并行模式都为非线程安全。
     */
    int flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX;
    if (sqlite3_open_v2([self.filePath UTF8String], &_db, flags, NULL) != SQLITE_OK) {
        SQLiteLog(@"打开数据库失败: '%s'", sqlite3_errmsg(_db));
        sqlite3_close_v2(_db);
        return;
    }
    //  如果是 temporary 或者 in-memory，则返回 NULL
    SQLiteLog(@"打开数据库: %s", sqlite3_db_filename(_db, "main"));
    /*
     设置多个对象同时修改数据时，重试的超时时间。注意：在事务中无效，但开起事务的保留锁。
     如果不设置则会‘database is locked’
     */
    if (sqlite3_busy_timeout(_db, 60 * 1000) != SQLITE_OK) {    //  设置重试是时间为60s
        SQLiteLog(@"等待文件锁超时错误: '%s'", sqlite3_errmsg(_db));
    }
}

- (void)closeDB {
    if (sqlite3_close_v2(_db) != SQLITE_OK) {
        SQLiteLog(@"关闭数据库失败: '%s'", sqlite3_errmsg(_db));
    }
}


#pragma mark -  表的操作
//_______________________________________________________________________________________________________________

- (BOOL)isValidSQL:(NSString*)sqlString {
    BOOL valid = YES;
    const char *sql = [sqlString UTF8String];
    sqlite3_stmt *stmt;
    if (sqlite3_prepare_v2(_db, sql, -1, &stmt, NULL) != SQLITE_OK) {
        valid = NO;
        SQLiteLog(@"数据库语句无效, SQL: %s", sql);
    }
    sqlite3_finalize(stmt);
    return valid;
}


- (BOOL)executeSQL:(NSString *)sqlString {
    BOOL success = YES;
    const char *sql = [sqlString UTF8String];
    if (sqlite3_exec(_db, sql, NULL, NULL, NULL) != SQLITE_OK) {
        success = NO;
        SQLiteLog(@"执行失败: '%s', SQL: '%s'", sqlite3_errmsg(_db), sql);
    }
    return success;
}


- (int)selectSQL:(NSString *)sqlString eachStmt:(sqlite3_stmt_block_t)block {
    const char *sql = [sqlString UTF8String];
    sqlite3_stmt *stmt;
    int i = 0;
    if (sqlite3_prepare_v2(_db, sql, -1, &stmt, NULL) == SQLITE_OK) {       //  这儿容易出现非法内存访问，检查是否为多线程串行模式
        while (sqlite3_step(stmt) == SQLITE_ROW) {                          //  遍历行
            block(i++, stmt);
        }
    } else {
        SQLiteLog(@"selectSQL 失败: '%s', SQL: '%s'", sqlite3_errmsg(_db), sql);
    }
    sqlite3_finalize(stmt);
    return i;
}

- (int)updateSQL:(NSString *)sqlString count:(int)count eachStmt:(sqlite3_stmt_block_t)block {
    const char *sql = [sqlString UTF8String];
    sqlite3_stmt *stmt;
    int i = 0;
    if (sqlite3_prepare_v2(_db, sql, -1, &stmt, NULL) == SQLITE_OK) {
        while (i < count) {
            sqlite3_clear_bindings(stmt);
            block(i++, stmt);
            if (sqlite3_step(stmt) != SQLITE_ROW) {
                sqlite3_reset(stmt);        //  step出错后，继续step之前需要reset，否则会出现SQLITE_MISUSE
            };
        }
    } else {
        SQLiteLog(@"updateSQL 失败: '%s', SQL: '%s'", sqlite3_errmsg(_db), sql);
    }
    sqlite3_finalize(stmt);
    return i;
}


@end
