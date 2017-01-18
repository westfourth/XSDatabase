//
//  XSDatabase+Base.h
//  XSDatabase
//
//  Created by xisi on 2017/1/15.
//  Copyright © 2017年 xisi. All rights reserved.
//

#import "XSDatabase.h"

/*!
    **************** 基础功能 ****************
 */
@interface XSDatabase (Base)

//! （可选）用户版本，多用于版本升级，该信息与主数据库文件有关
@property (atomic) int userVersion;


#pragma mark -  多用户环境
//_______________________________________________________________________________________________________________

//! 默认数据库，文件名为：Database.db ，已经打开
+ (XSDatabase *)defaultDatabase;

//! 获取当前数据库。（不存在时，会返回默认数据库）
+ (XSDatabase *)currentDatabase;

//! 设置当前数据库。（如果未打开，则打开）
+ (void)setCurrentDatabase:(XSDatabase *)database;

/*!
    根据ID找到其对应XSDatabase；如果没有，则创建。

    数据库文件：'./Library/Caches/$(ID).db'
 */
+ (XSDatabase *)databaseWithID:(NSString *)ID;


#pragma mark -  基于字典、数组的操作
//_______________________________________________________________________________________________________________

/*!
     查找记录（注意：少数情况下结果可能与申明的类型不同）。
     
     支持多表联合查询，不支持多个语句。
     如果有多个语句，则只有第一个起作用。
 */
- (NSMutableArray *)selectSQL:(NSString *)sqlString;


/*!
     插入记录（原理：根据dict中的key，寻找key在表中的列位置）
     
     @param  sqlString   格式例如：replace into tb (ID, image, score) values (:ID, :image, :score)。
     @param  dict    key为NSString，value为【 NSNumber、NSString、NSNull，其它自动使用archivedDataWithRootObject:转化为NSData 】。
 */
- (BOOL)updateSQL:(NSString *)sqlString dict:(NSDictionary *)dict;


#pragma mark -  分离附加数据库文件（可用于多用户环境中）
//_______________________________________________________________________________________________________________

/*!
     附加数据库文件到当前数据库文件，指定数据库名。
     
     @warning    databaseName与tableName都必须以字母或下划线开头（与C语言变量命名规范一样）。
     A:  a123.b123   -   表示a123数据库中的b123表
     B:  'a123.b123' -   表示main数据库中的a123.b123表
     C:  "a123.b123" -   同B
     
     @example    attach "/Users/xisi/Desktop/123.db" as a123;
     create table if not exists a123.b123 (name, text);
 */
- (BOOL)attachDBFile:(NSString *)dbFile asDBName:(NSString *)dbName;

//! 分离数据库
- (BOOL)detachDBName:(NSString *)dbName;


#pragma mark - 事务支持
//_______________________________________________________________________________________________________________

//! 如果为NO，说明正处在用户事务【下面三个方法】。
- (BOOL)isAutoCommit;

//! 开始事务（注意：事务串行执行）。    （注意：cannot start a transaction within a transaction）
- (BOOL)beginTransaction;

//! 提交事务（结束事务）。
- (BOOL)commitTransaction;

//! 回滚事务（结束事务）。
- (BOOL)rollbackTransaction;


#pragma mark - 事务保存点支持【未做多线程测试】
//_______________________________________________________________________________________________________________

//! 保存点。
- (BOOL)savepoint:(NSString *)savepoint;

//! 释放保存点。
- (BOOL)releaseSavepoint:(NSString *)savepoint;

//! 回滚到指定保存点。
- (BOOL)rollbackToSavepoint:(NSString *)savepoint;


#pragma mark -  内置功能
//_______________________________________________________________________________________________________________

//! 判断是否是完整的SQL语句。
+ (BOOL)isCompleteSQL:(NSString *)sql;

//! SQLite当前使用了多少内存（以Byte为单位）。
+ (int)memoryUsed;

//! SQLite内存使用最多的时候是多少Byte
+ (int)memoryHighWater;

//! 中断当前数据库操作(注意：在同一线程中中断是无效的。并且不一定有效)。
- (void)interrupt;

//! 最后一次执行INSERT的行ID。
- (int)lastInsertRowID;

//! 最后一次执行INSERT、UPDATE、DELETE受影响的行数。
- (int)changes;

@end
