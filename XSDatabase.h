//
//  Database.h
//  DataBaseTest
//
//  Created by xisi on 13-12-10.
//  Copyright (c) 2013年 77. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <sqlite3.h>

#if TARGET_IPHONE_SIMULATOR
    #define SQLiteLog(format, ...)      NSLog(@"___SQLite " format, ##__VA_ARGS__)
#else
    #define SQLiteLog(format, ...)
#endif


typedef void (^sqlite3_stmt_block_t) (int index, sqlite3_stmt *stmt);       //  index >= 0


/*!
    对SQLite数据库的简易封装，支持多线程中的多个对象对同一数据库进行增删改查、事务操作。
    
    **************** 核心功能 ****************
 
    @undoen     未做多线程的串行模式改为并行模式
    @done       已做内存泄漏测试，无泄漏。
 */
@interface XSDatabase : NSObject {
    sqlite3 *_db;                           //!<
}

#pragma mark -  （可选）用于打开其他路径的数据库
//_______________________________________________________________________________________________________________

//! 指定数据库文件（如果不指定，则在内存中建立临时文件）。
@property (atomic, strong) NSString *filePath;

@property (atomic, readonly) BOOL isOpen;

//! 打开数据库（如果不存在，则创建新的数据库文件）。
- (void)openDB;

//! 关闭数据库
- (void)closeDB;


#pragma mark -  数据库基础语句
//_______________________________________________________________________________________________________________

/*!
    判断数据库语句是否有效。（不支持多个语句，sqlite3_prepare_v2()理由同上）
 
    只是编译SQL，不执行，不会影响到表；数据库语句是否有效与数据库结构有关。
 */
- (BOOL)isValidSQL:(NSString*)sqlString;

/*!
    执行数据库语句。
    
    支持多个语句: @"update company set code='1111'; update company set sortkey='2222'";

    执行插入记录语句时转义[']为['']，而不是[\']
 */
- (BOOL)executeSQL:(NSString *)sqlString;

/*!
    查找记录，需要自己解开数据
 
    支持多表联合查询，不支持多个语句；如果有多个语句，则只有第一个起作用。 详细请查看sqlite3_prepare_v2()最后一个参数的解释。
 
    @param  block   多次回调，使用sqlite3_column_*系列函数取值。    不可异步
    @return 返回的行数
 */
- (int)selectSQL:(NSString *)sqlString eachStmt:(sqlite3_stmt_block_t)block;

/*!
    插入/更新 数据。（不支持多个语句，sqlite3_prepare_v2()理由同上）
 
    @note   批量时，请手动开启事务
 
    @param  block   多次回调，使用sqlite3_bind_*系列函数绑定值。    不可异步
    @return 实际更新的行数（i <= count）
 */
- (int)updateSQL:(NSString *)sqlString count:(int)count eachStmt:(sqlite3_stmt_block_t)block;


@end
