package Project2::Gantt::SpanInfo;

use Mojo::Base -base,-signatures;

use Project2::Gantt::TextUtils;

use Mojo::Log;

our $DATE = '2024-02-05'; # DATE
our $VERSION = '0.011';

has canvas => undef;
has task   => undef;
has skin   => undef;

has log    => sub { Mojo::Log->new };

sub write($self,$height) {
	$self->_writeInfo($height);
}

sub _writeInfo($self, $height) {
	my $log      = $self->log;
	my $task	 = $self->task;
	my $bgcolor	 = $self->skin->primaryFill;
	my $fontFill = $self->skin->primaryText;
	my $canvas	 = $self->canvas;

	$bgcolor     = $self->skin->secondaryFill if $task->isa("Project2::Gantt");
	$fontFill    = $self->skin->secondaryText if $task->isa("Project2::Gantt");

	$canvas->box(
		color  => $bgcolor,
		xmin   => 0,
		ymin   => $height,
		xmax   => $self->skin->descriptionSize,
		ymax   => $height + 17,
		filled => 1,
	);

	$canvas->box(
		color  => $bgcolor,
		xmin   => $self->skin->descriptionSize,
		ymin   => $height,
		xmax   => $self->skin->titleSize,
		ymax   => $height + 17,
		filled => 1,
	);

	$log->debug(truncate($task->description,$self->skin->descriptionSize));

	my $description = truncate($task->description, $self->skin->descriptionSize);
	$log->debug("_writeInfo description=$description");
	$canvas->string(
		x      => 2,
		y      => $height + 12,
		string => $description,
		font   => $self->skin->font,
		size   => 10,
		aa     => 1,
		color  => $fontFill,
	);

	# if this is a task, write name... sub-projects aren't associated with a specific resource
	if($task->isa("Project2::Gantt::Task")){
		my $name = truncate($task->resources->[0]->name,$self->skin->resourceSize);
		$log->debug("_writeInfo name=$name");
		$canvas->string(
			x      => $self->skin->resourceStartX,
			y      => $height + 12,
			string => $name,
			font   => $self->skin->font,
			size   => 10,
			aa     => 1,
			color  => 'black',
		);
	}
}

1;
