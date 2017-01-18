//
//  XSDatabaseModel.h
//  XSDatabase
//
//  Created by xisi on 2017/1/17.
//  Copyright © 2017年 xisi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "XSDatabase+Base.h"

/*!
    数据库模型。（数据量比较大时，请具体优化相关类）
 
    手动建表：可以把所有的建表语句写在一个文件中，然后执行一下就可以了。 所以自动建表没多大意义。
 
    @warning    表中必须得有主键，不然该模型的增、删、改都不能用。
 
    @property支持的类型：所有NSNumber基础类型、NSNumber、NSString、NSDate。
 */
@interface XSDatabaseModel : NSObject

//  查询，格式：select * from $(TABLE) whereSql;
+ (NSArray<XSDatabaseModel *> *)objectsWhere:(NSString *)whereSql;

//  删除所有记录
+ (BOOL)deleteAll;

- (BOOL)delete;

- (BOOL)insert;

- (BOOL)insertOrReplace;

- (BOOL)update;

@end
