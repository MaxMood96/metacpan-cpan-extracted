package PDK::Device::Concern::Dumper;

use utf8;
use v5.30;
use Moose::Role;
use Carp       qw(croak);
use File::Path qw(make_path);
use namespace::autoclean;
use Encode::Guess;


has month => (
  is      => 'ro',
  default => sub {
    my $month = `date +%Y-%m`;
    chomp($month);
    return $month;
  },
);

has date => (
  is      => 'ro',
  default => sub {
    my $date = `date +%Y-%m-%d`;
    chomp($date);
    return $date;
  },
);

has workdir => (
  is      => 'rw',
  default => sub {
    my $value = $ENV{PDK_DEVICE_HOME};
    _debug_init("从环境变量中加载并设置 workdir：($value)") if defined $value;
    return $value // glob("~");
  },
);

has debug => (
  is      => 'rw',
  isa     => 'Int',
  default => sub {
    my $value = $ENV{PDK_DEVICE_DEBUG};
    _debug_init("从环境变量中加载并设置 debug：($value)") if defined $value;
    return $value // 0;
  },
);


sub now {
  my $now = `date "+%Y-%m-%d %H:%M:%S"`;
  chomp($now);
  return $now;
}

sub dump {
  my ($self, $msg) = @_;

  $msg .= ';' unless $msg =~ /^\s*$/ || $msg =~ /[,，！!。.]$/;

  my $text = $self->now() . " - [debug] $msg";
  if ($self->debug == 1) {
    say $text;
  }
  elsif ($self->debug > 1) {
    my $basedir = $ENV{PDK_DEVICE_HOME} // glob("~");
    my $workdir = "$basedir/dump/$self->{month}/$self->{date}";
    make_path($workdir) unless -d $workdir;

    my $filename = "$workdir/$self->{host}_dump.txt";
    open(my $fh, '>>encoding(UTF-8)', $filename) or croak "无法打开文件 $filename 进行写入: $!";
    print $fh "$text\n"                          or croak "写入文件 $filename 失败: $!";
    close($fh)                                   or croak "关闭文件句柄 $filename 失败: $!";
  }
}

sub write_file {
  my ($self, $config, $name) = @_;

  croak("必须提供非空配置信息") unless !!$config;
  $name //= "$self->{host}.txt";

  my $workdir = "$self->{workdir}/$self->{month}/$self->{date}";
  make_path($workdir) unless -d $workdir;

  my $enc = Encode::Guess->guess($config);
  if (ref $enc) {
    eval { $config = $enc->decode($config); };
    if (!!$@) {
      $self->dump("[write_file] $name 字符串解码失败：$@");
    }
  }
  else {
    $self->dump("[write_file] $name 无法猜测编码: $enc");
  }

  $self->dump("[write_file] 准备将数据写入本地文件: ($workdir/$name)");

  my $filename = "$workdir/$name";
  open(my $fh, '>>:encoding(UTF-8)', $filename) or croak "无法打开文件 $filename 进行写入: $!";
  print $fh $config                             or croak "写入文件 $filename 失败: $!";
  close($fh)                                    or croak "关闭文件句柄 $filename 失败: $!";

  $self->dump("[write_file] 成功写入文本数据到文件: $filename");

  return {success => 1};
}

sub initPdkDevice {
  my ($self, $param) = @_;

  croak "[initPdkDevice] \$param必须是一个哈希引用" unless ref($param) eq 'HASH';
  my $host = $param->{ip} or croak "必须正确提供目标设备的IP地址";

  my $username = $param->{username} || $ENV{PDK_DEVICE_USERNAME};
  my $password = $param->{password} || $ENV{PDK_DEVICE_PASSWORD};

  croak "[initPdkDevice] 必须提供登录设备的账户密码或设置相关的环境变量：PDK_DEVICE_USERNAME，PDK_DEVICE_PASSWORD;"
    unless ($username && $password);

  my $class = $param->{pdk_device_module};
  eval "use $class; 1" or croak "[initPdkDevice] 加载模块失败: $class";

  $self->dump("[initPdkDevice] 尝试自动加载模块 $class，并初始化对象($param->{name}/$host)");
  my $device = $class->new(host => $host, username => $username, password => $password)
    or croak "[initPdkDevice] 实例化模块失败: $class";

  return $device;
}

sub assignPdkModules {
  my ($self, @args) = @_;

  my @devices = @args == 1 && ref $args[0] eq 'ARRAY' ? @{$args[0]} : @args;

  my $msg = sprintf("[assignPdkModules] 自动装配 PDK 模块中，共计: %d 台设备", scalar @devices);
  $self->dump($msg);

  state $os_to_module = {
    qr/^Cisco|ios/i   => 'PDK::Device::Cisco',
    qr/^nx-os/i       => 'PDK::Device::Cisco::Nxos',
    qr/^PAN-OS/i      => 'PDK::Device::Paloalto',
    qr/^Radware/i     => 'PDK::Device::Radware',
    qr/^H3C|Comware/i => 'PDK::Device::H3c',
    qr/^Hillstone/i   => 'PDK::Device::Hillstone',
    qr/^junos/i       => 'PDK::Device::Juniper',
  };

  for my $device (@devices) {
    croak "[assignPdkModules] 设备属性必须包含 'ip' 和 'name' 属性" unless exists $device->{ip} && exists $device->{name};

    $device->{username} //= $ENV{PDK_DEVICE_USERNAME};
    $device->{password} //= $ENV{PDK_DEVICE_PASSWORD};

    my ($module) = grep { $device->{os} =~ $_ } keys %$os_to_module;
    croak "[assignPdkModules] 暂不兼容的 OS：$device->{os}，请联系管理员" unless !!$module;
    $device->{pdk_device_module} = $os_to_module->{$module};

    $device->{name} =~ s/\..*$//;
    $self->dump("[assignPdkModules] ($device->{name}/$device->{ip}) 成功装配 PDK：$device->{pdk_device_module}");
  }

  $msg = sprintf("[assignPdkModules] 已完成自动装配 PDK 模块，共计: %d 台设备", scalar @devices);
  $self->dump($msg);

  return wantarray ? @devices : $devices[0];
}

sub _debug_init {
  my ($msg) = @_;
  my $now = `date "+%Y-%m-%d %H:%M:%S"`;
  chomp($now);
  my $text = $now . " - [debug] $msg\n";
  binmode(STDERR, ':utf8');
  print STDERR $text if $ENV{PDK_DEVICE_DEBUG};
}

1;
