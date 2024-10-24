package PDK::Device::Concern::Netdisco;

use v5.30;
use Moose;
use Carp qw(croak);
use Parallel::ForkManager;
use Thread::Queue;
use namespace::autoclean;

with 'PDK::Device::Concern::Dumper';

has workdir => (
  is      => 'rw',
  default => sub {
    my $value = $ENV{PDK_DEVICE_NETDISCO_HOME};
    PDK::Device::Concern::Dumper::_debug_init("从环境变量中加载并设置 workdir：($value)") if defined $value;
    return $value // glob("~");
  },
);

has debug => (
  is      => 'rw',
  default => sub {
    my $value = $ENV{PDK_DEVICE_NETDISCO_DEBUG};
    PDK::Device::Concern::Dumper::_debug_init("从环境变量中加载并设置 debug：($value)") if defined $value;
    return $value // 0;
  },
);

has result => (is => 'rw', default => sub { {success => [], fail => []} },);

sub exploreTopologyJob {
  my ($self, $devices) = @_;

  eval {
    $devices = ref($devices) eq 'ARRAY' ? $devices : [$devices];
    $devices = $self->assignAttributes($devices);
    my $count = scalar(@{$devices});
    $self->dump("开始任务：并行执行 ($count) 台设备的接口描述自动修正任务");
  };
  if (!!$@) {
    croak "自动加载并装配模块抛出异常: $@";
  }

  my $pm    = Parallel::ForkManager->new(10);
  my $queue = Thread::Queue->new();

  $pm->run_on_finish(sub {
    my (undef, undef, undef, undef, undef, $data) = @_;
    $queue->enqueue($data) if defined $data;
  });

  foreach my $device (@{$devices}) {
    $pm->start and next;
    my $status = $self->startExploreTopology($device);
    $pm->finish(0, $status);
  }
  $pm->wait_all_children;

  $self->process_results($queue);
}

sub process_results {
  my ($self, $queue) = @_;

  my $result = $self->{result};
  while (my $data = $queue->dequeue_nb()) {
    push @{$result->{$_}}, @{$data->{$_}} for qw(success fail);
  }

  for my $type (qw(success fail)) {
    if (@{$result->{$type}}) {
      my $text = join("\n", @{$result->{$type}});
      my $flag = $type eq 'success' ? '成功' : '失败';
      $self->write_file($text, "邻居发现自动修正接口描述${flag}_设备清单");
    }
  }
}

sub startExploreTopology {
  my ($self, $param) = @_;
  $self->dump("激活任务：对设备($param->{name}/$param->{ip})自动进行邻居发现");

  my $name = $param->{name};
  my $ip   = $param->{ip};

  my $result = $self->exploreTopology($param);
  my $status = $self->{result};
  if ($result->{success}) {
    push @{$status->{success}}, $self->now . " - 设备 $name($ip) 邻居发现成功";
    my $filename = "${name}_${ip}_netdisco.txt";
    $self->write_file($result->{result}, $filename);
  }
  else {
    push @{$status->{fail}}, $self->now . " - 设备 $name($ip) 邻居发现失败: $result->{reason}";
  }

  return $status;
}

sub exploreTopology {
  my ($self, $param) = @_;
  $self->dump("开始任务：对设备($param->{name}/$param->{ip})自动进行邻居发现");

  my $result;
  eval {
    my $device            = $self->initPdkDevice($param);
    my $pdk_device_module = $param->{pdk_device_module};

    if ($pdk_device_module =~ /h3c/i) {
      $result = $self->explore_h3c($device);
    }
    elsif ($pdk_device_module =~ /cisco/i) {
      $result = $self->explore_cisco($device);
    }
    else {
      my $msg = "暂不支持解析模块的邻居发现：$pdk_device_module";
      $self->dump($msg);
      warn $msg;
      $result = {success => 0, reason => $msg};
    }
  };
  if (!!$@) {
    $result = {success => 0, reason => $@};
  }

  return $result;
}

sub explore_h3c {
  my ($self, $device) = @_;
  eval {
    require PDK::Concern::Netdisco::H3c;
    my $nd = PDK::Concern::Netdisco::H3c->new(device => $device);
    return $nd->explore_topology();
  } or do {
    die "无法正常加载模块(PDK::Concern::Netdisco::H3c)并初始化对象：$@";
  };
}

sub explore_cisco {
  my ($self, $device) = @_;
  eval {
    require PDK::Concern::Netdisco::Cisco;
    my $nd = PDK::Concern::Netdisco::Cisco->new(device => $device);
    return $nd->explore_topology();
  } or do {
    die "无法正常加载模块(PDK::Concern::Netdisco::Cisco)并初始化对象：$@";
  };
}

__PACKAGE__->meta->make_immutable;
1;
