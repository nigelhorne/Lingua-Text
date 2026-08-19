# Generated from Makefile.PL using makefilepl2cpanfile

requires 'perl', '5.6.2';

requires 'Carp';
requires 'Exporter';
requires 'ExtUtils::MakeMaker', '6.64';   # 6.64 for TEST_REQUIRES
requires 'HTML::Entities';
requires 'I18N::LangTags::Detect';
requires 'Object::Configure';
requires 'Params::Get';
requires 'Scalar::Util';

on 'test' => sub {
	requires 'IPC::System::Simple';
	requires 'Test::Carp';
	requires 'Test::DescribeMe';
	requires 'Test::Most';
	requires 'Test::Needs';
	requires 'Test::NoWarnings';
};

on 'develop' => sub {
	requires 'Devel::Cover';
	requires 'Perl::Critic';
	requires 'Test::Pod';
	requires 'Test::Pod::Coverage';
};
