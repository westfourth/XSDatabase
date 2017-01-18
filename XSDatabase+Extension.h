//
//  XSDatabase+Extension.h
//  XSDatabase
//
//  Created by xisi on 2017/1/15.
//  Copyright © 2017年 xisi. All rights reserved.
//

#import "XSDatabase+Base.h"

/*!
    **************** 扩展功能（一般不导入到项目中）****************
 */
@interface XSDatabase (Extension)

#pragma mark - 查询
//_______________________________________________________________________________________________________________

//! 当前连接的数据库列表。
- (NSMutableArray *)databaseList;

//! （表、视图）列表，不包括临时表。
- (NSMutableArray *)tableList;

//! （表、视图）信息。如果多个数据库，则根据'.'号分割出数据库、表
- (NSMutableArray *)tableInfo:(NSString *)dbTable;

//! 是否存在指定（表、视图）。
- (BOOL)hasTable:(NSString *)dbTable;


#pragma mark -  删除
//_______________________________________________________________________________________________________________

//! 删除数据库（表）中所有的行。（视图为只读）
- (BOOL)deleteAllRowsFromTable:(NSString *)dbTable;

//! 删除指定表（表、视图）。
- (BOOL)deleteTable:(NSString *)dbTable;

//! 删除所有（表、视图）
- (BOOL)deleteAll;


#pragma mark -  其他
//_______________________________________________________________________________________________________________

/*!
     构建数据库语句，例如: replace into (ID, name) values (:ID, :name)。
     
     取出表字段名columnNamesArray，与dict.allKeys对比，取交集。
     
     @code
         NSString *sqlString = [self SQLReplaceForTable:dbTable dict:array.firstObject];
         [self replaceIntoSQL:sqlString dict:dict];
     @endcode
 */
- (NSString *)SQLReplaceForTable:(NSString *)dbTable dict:(NSDictionary *)dict;

@end
