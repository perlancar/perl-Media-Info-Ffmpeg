package Media::Info::Ffmpeg;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;
use Log::ger;

use Capture::Tiny qw(capture);
use IPC::System::Options 'system', -log=>1;
use Perinci::Sub::Util qw(err);

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(
                       get_media_info
               );

our %SPEC;

$SPEC{get_media_info} = {
    v => 1.1,
    summary => 'Return information on media file/URL, using ffmpeg',
    args => {
        media => {
            summary => 'Media file',
            schema  => 'str*',
            pos     => 0,
            req     => 1,
        },
    },
    deps => {
        prog => 'ffmpeg',
    },
};
sub get_media_info {
    require File::Which;

    my %args = @_;

    File::Which::which("ffmpeg")
          or return err(412, "Can't find ffmpeg in PATH");
    my $media = $args{media} or return err(400, "Please specify media");

    # make sure user can't sneak in cmdline options to ffmpeg
    $media = "./$media" if $media =~ /\A-/;

    my ($stdout, $stderr, $exit) = capture {
        local $ENV{LANG} = "C";
        system("ffmpeg", "-i", $media);
    };

    return err(500, "ffmpeg doesn't show information")
        unless $stderr =~ /^Input \#0/m;

    my $info = {};
    $info->{duration}      = $1*3600+$2*60+$3 if $stderr =~ /^\s*Duration: (\d+):(\d+):(\d+\.\d+)/m;

    # XXX multiple video streams info
    if ($stderr =~ /^\s*Stream.+?: Video: (.+)/m) {
        my $video_info = $1;
        $video_info =~ /^(\w+)/; $info->{video_format} = uc($1);
        $video_info =~ /(\d+)x(\d+)/ and do {
            $info->{video_width}  = $1;
            $info->{video_height} = $2;
        };
        $video_info =~ /(\d+(?:\.\d+)?) fps/ and $info->{video_fps} = $1;
        $video_info =~ m!(\d+(?:\.\d+)?) kb/s! and $info->{video_bitrate} = $1*1024;
    }

    # XXX multiple audio streams info
    if ($stderr =~ /\s*Stream.+?: Audio: (.+)/m) {
        my $audio_info = $1;
        $audio_info =~ /^(\w+)/; $info->{audio_format} = uc($1);
        $audio_info =~ /(\d+(?:\.\d+)?) Hz/ and $info->{audio_rate} = $1;
        $audio_info =~ m!(\d+(?:\.\d+)?) kb/s! and $info->{audio_bitrate} = $1*1024;
    }

    [200, "OK", $info, {"func.raw_output"=>$stderr}];
}

1;
# ABSTRACT:

=head1 SYNOPSIS

Use directly:

 use Media::Info::Ffmpeg qw(get_media_info);
 my $res = get_media_info(media => '/home/steven/celine.avi');

or use via L<Media::Info>.

Sample result:

 [
   200,
   "OK",
   {
     audio_bitrate => 128000,
     audio_format  => "aac",
     audio_rate    => 44100,
     duration      => 2081.25,
   },
   {
     "func.raw_output" => "ffmpeg version 0.8.17-...",
   },
 ]


=head1 SEE ALSO

L<Media::Info>

=cut
