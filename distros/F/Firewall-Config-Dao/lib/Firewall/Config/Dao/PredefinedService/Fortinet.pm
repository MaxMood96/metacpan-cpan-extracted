package Firewall::Config::Dao::PredefinedService::Fortinet;

#------------------------------------------------------------------------------
# 加载扩展模块
#------------------------------------------------------------------------------
use Moose;
use namespace::autoclean;

#------------------------------------------------------------------------------
# 继承 Firewall::Config::Dao::PredefinedService::Role 方法属性
#------------------------------------------------------------------------------
with 'Firewall::Config::Dao::PredefinedService::Role';

#------------------------------------------------------------------------------
# 具体实现 _buildPreDefinedServiceTableName 方法，返回数据表
#------------------------------------------------------------------------------
sub _buildPreDefinedServiceTableName {
  return 'fw_predef_service_fortinet';
}

#------------------------------------------------------------------------------
# 具体实现 vendor 方法
#------------------------------------------------------------------------------
sub vendor {
  my $self = shift;

  # 切割 vendor 字段
  my $vendor = ( split( /::/, __PACKAGE__ ) )[-1];

  # 防护计算结果
  return $vendor;
}

__PACKAGE__->meta->make_immutable;
1;
