=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2017] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 CONTACT

 Will McLaren <wm2@ebi.ac.uk>
    
=cut

=head1 NAME

 CADD

=head1 SYNOPSIS

 mv CADD.pm ~/.vep/Plugins
 ./vep -i variations.vcf --plugin CADD,whole_genome_SNVs.tsv.gz,InDels.tsv.gz

=head1 DESCRIPTION

 A VEP plugin that retrieves CADD scores for variants from one or more
 tabix-indexed CADD data files.
 
 Please cite the CADD publication alongside the VEP if you use this resource:
 http://www.ncbi.nlm.nih.gov/pubmed/24487276
 
 The tabix utility must be installed in your path to use this plugin. The CADD
 data files can be downloaded from
 http://cadd.gs.washington.edu/download
 
=cut

package CADD;

use strict;
use warnings;

use Bio::EnsEMBL::Utils::Sequence qw(reverse_comp);

use Bio::EnsEMBL::Variation::Utils::BaseVepTabixPlugin;

use base qw(Bio::EnsEMBL::Variation::Utils::BaseVepTabixPlugin);

sub new {
  my $class = shift;
  
  my $self = $class->SUPER::new(@_);

  $self->expand_left(0);
  $self->expand_right(0);

  $self->get_user_params();

  return $self;
}

sub feature_types {
  return ['Feature','Intergenic'];
}

sub get_header_info {
  my $self = shift;
  return {
    CADD_PHRED => 'PHRED-like scaled CADD score',
    CADD_RAW   => 'Raw CADD score'
  }
}

sub run {
  my ($self, $tva) = @_;
  
  my $vf = $tva->variation_feature;
  
  # get allele, reverse comp if needed
  my $allele = $tva->variation_feature_seq;
  reverse_comp(\$allele) if $vf->{strand} < 0;
  
  return {} unless $allele =~ /^[ACGT-]+$/;

  my ($res) = grep {
    $_->{alt}   eq $allele &&
    $_->{start} eq $vf->{start} &&
    $_->{end}   eq $vf->{end}
  } @{$self->get_data($vf->{chr}, $vf->{start} - 2, $vf->{end})};

  return $res ? $res->{result} : {};
}

sub parse_data {
  my ($self, $line) = @_;

  my ($c, $s, $ref, $alt, $raw, $phred) = split /\t/, $line;

  # do VCF-like coord adjustment for mismatched subs
  my $e = ($s + length($ref)) - 1;
  if(length($alt) != length($ref)) {
    $s++;
    $ref = substr($ref, 1);
    $alt = substr($alt, 1);
    $ref ||= '-';
    $alt ||= '-';
  }

  return {
    alt => $alt,
    start => $s,
    end => $e,
    result => {
      CADD_RAW   => $raw,
      CADD_PHRED => $phred
    }
  };
}

sub get_start {
  return $_[1]->{start};
}

sub get_end {
  return $_[1]->{end};
}

1;