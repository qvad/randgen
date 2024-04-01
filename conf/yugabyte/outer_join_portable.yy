# Copyright (C) 2008-2010 Sun Microsystems, Inc. All rights reserved.
# Use is subject to license terms.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301
# USA

################################################################################
# outer_join_portable.yy
# Purpose:  Random Query Generator grammar for testing larger (6 - 10 tables) JOINs
# Tuning:   Please tweak the rule table_or_joins ratio of table:join for larger joins
#           NOTE:  be aware that larger (15-20 tables) queries can take far too
#                  long to run to be of much interest for fast, automated testing
#
# Notes:    This grammar is designed to be used with gendata=conf/optimizer/outer_join.zz
#           It can be altered, but one will likely need field names
#           Additionally, it is not recommended to use the standard RQG-produced
#           tables as they way we pick tables can result in the use of
#           several large tables that will bog down a generated query
#
#           Please rely this variant of this grammar if
#           doing 3-way comparisons as it has altered code that will produce
#           more standards-compliant queries for use with other DBMS's
#
#           We keep the outer_join grammar as it is in order to also test 
#           certain MySQL-specific syntax variants.
################################################################################

################################################################################
# we have the perl code here as these variables are helpers for generating
# queries
# nonaggregates -  holds all nonaggregate fields used, stored as the alias used
#               such as field1, field2...
# tables - counter used to generate accurate table aliases - table1, table2..
# fields - same as tables
#
# NOTE:  refer to rule nonaggregate_select_item to see the next two items
#        in use.
#
# table_alias_set - we store aliases for creating standards-compliant
#                   field references in GROUP BY and HAVING clauses
# int_field_set - we only use integer fields in this grammar and we
#                 create this helper array for the same purposes as
#                 table_alias_set
#
# YB:
# - Change table_alias_set to store the ids only
# - Add the following variables:
#   tables_reqd - max table id used in the SELECT-list so we can add missing
#                 tables to the FROM-clause.
#   agg_field_table_alias_set - table alias ids for aggregate function
#                 arguments.
################################################################################

################################################################################
# YB: Caution: some of the rules in this grammar calls the "expand" subroutine,#
# an undocumented internal entry point that can stop working with future       #
#  Generator code changes.                                                     #
################################################################################

query:
  { $min_tables = 0; @table_alias_set = (1, 1, 1, 1, 2, 2, 2, 3, 4, 5, 1, 1, 2) ; "" }
  { @int_field_set = ("pk", "col_int", "col_int_key", "col_bigint", "col_bigint_key", "col_decimal_5_2", "col_decimal_5_2") ; "" } 
  { $gby = "";  @nonaggregates = () ;  @aggregates = (); $t1 = 1; @st1 = (); $tables = 0 ; $fields = 0 ;  "" }
  hints query_type ;

################################################################################
# YB: Randomly add a hint set that encourages Batched Nested Loop plans
################################################################################

hints:
  | | | |
  /*+ disable_hashmerge */ |
  /*+ disable_seqscan disable_hashagg disable_sort */ |
  /*+ disable_seqscan disable_hashagg disable_sort disable_hashmerge */ ;

disable_hashmerge: Set(enable_hashjoin off) Set(enable_mergejoin off) Set(enable_material off) ;

disable_seqscan: | | Set(enable_seqscan OFF) ;

disable_sort: | | Set(enable_sort OFF) ;

disable_hashagg: | | Set(enable_hashagg OFF) ;


################################################################################
# We have various query_type's so that we can ensure more syntactically correct
# queries are generated.  Certain mixes have different requirements
# mixed - regular fields + aggregates
# simple - regular fields only
# aggregate - aggregates only
################################################################################

query_type:
  simple_select | simple_select | mixed_select | mixed_select | mixed_select | aggregate_select ;

mixed_select:
        { $stack->push() } SELECT distinct straight_join select_option select_list FROM join_list WHERE where_list group_by_clause having_clause order_by_clause { $stack->pop(undef) } ;

simple_select:
        { $stack->push() } SELECT distinct straight_join select_option simple_select_list FROM join_list WHERE where_list  optional_group_by having_clause order_by_clause { $stack->pop(undef) } ;

aggregate_select:
        { $stack->push() } SELECT distinct straight_join select_option aggregate_select_list FROM join_list WHERE where_list optional_group_by having_clause order_by_clause { $stack->pop(undef) } ;

distinct: DISTINCT | | | |  ;

select_option:  | | | | | | | | | SQL_SMALL_RESULT ;

straight_join:  | | | | | | | | | | | STRAIGHT_JOIN ;

select_list:
	new_select_item |
	new_select_item , select_list |
        new_select_item , select_list ;

simple_select_list:
        nonaggregate_select_item |
        nonaggregate_select_item , simple_select_list |
        nonaggregate_select_item , simple_select_list ;

aggregate_select_list:
        aggregate_select_item | aggregate_select_item |
        aggregate_select_item, aggregate_select_list ;

new_select_item:
        nonaggregate_select_item |
        nonaggregate_select_item |        
        nonaggregate_select_item |
        nonaggregate_select_item |        
        nonaggregate_select_item |
	aggregate_select_item ;

################################################################################
# We differ from the main variant of the grammar here
# We pop from the previously populated helper arrays table_alias_set and 
# int_field_set so that we can generate and store fields in the form:
# <table_alias> . <field_name> AS field<number>
# <table_alias> . <field_name> is stored in the @nonaggregates array and
# used in the GROUP BY statements - this is standards-compliant and won't
# throw javadb or postgres for a loop
################################################################################

nonaggregate_select_item:
        { my $n = $prng->arrayElement(\@table_alias_set); $min_tables = $n if $min_tables < $n; my $x = "table".$n." . ".$prng->arrayElement(\@int_field_set); push @nonaggregates , $x ; $x } AS {my $f = "field".++$fields ; $f };

aggregate_select_item:
	{ my $x = join("", expand($rule_counters,$rule_invariants, "new_aggregate")); push @aggregates, $x; $x } AS { "field".++$fields };

new_aggregate:
	aggregate table_alias . _field_int ) |
	aggregate table_alias . _field_int ) |
	aggregate table_alias . _field_int ) |
	literal_aggregate ;

new_aggregate_existing_table_item:
	aggregate existing_table_item . _field_int ) |
	aggregate existing_table_item . _field_int ) |
	aggregate existing_table_item . _field_int ) |
	literal_aggregate ;

table_alias:
	{ my $n = $prng->arrayElement(\@table_alias_set); $min_tables = $n if $min_tables < $n; "table".$n };

################################################################################
# We make use of the new RQG stack in order to generate more interesting
# queries.  Please refer to the RQG documentation for a more in-depth discussion
# of how the stack functions
################################################################################
	
join_list:
        join join_missing_table_items ;

join:
     ( { push @st1, $t1; $t1 = $tables + 1; "" }
       { $stack->push() }
       table_or_join 
       { $stack->set("left",$stack->get("result")); }
       left_right outer JOIN table_or_join
       ON
       join_condition
       { $t1 = pop @st1; "" } ) ;

join_condition:
   int_condition | char_condition |
   int_condition | char_condition |
   int_condition and_or where_item |
   char_condition and_or where_item ;

int_condition: 
   { my $left = $stack->get("left"); my %s=map{$_=>1} @$left; my @r=(keys %s); my $table_string = $prng->arrayElement(\@r); my @table_array = split(/AS/, $table_string); $table_array[1] } . _field_int_indexed = 
   { my $right = $stack->get("result"); my %s=map{$_=>1} @$right; my @r=(keys %s); my $table_string = $prng->arrayElement(\@r); my @table_array = split(/AS/, $table_string); $table_array[1] } . _field_int_indexed
   { my $left = $stack->get("left");  my $right = $stack->get("result"); my @n = (); push(@n,@$right); push(@n,@$left); $stack->pop(\@n); return undef } |
   { my $left = $stack->get("left"); my %s=map{$_=>1} @$left; my @r=(keys %s); my $table_string = $prng->arrayElement(\@r); my @table_array = split(/AS/, $table_string); $table_array[1] } . _field_int_indexed =
   { my $right = $stack->get("result"); my %s=map{$_=>1} @$right; my @r=(keys %s); my $table_string = $prng->arrayElement(\@r); my @table_array = split(/AS/, $table_string); $table_array[1] } . _field_int
   { my $left = $stack->get("left");  my $right = $stack->get("result"); my @n = (); push(@n,@$right); push(@n,@$left); $stack->pop(\@n); return undef } |
   { my $left = $stack->get("left"); my %s=map{$_=>1} @$left; my @r=(keys %s); my $table_string = $prng->arrayElement(\@r); my @table_array = split(/AS/, $table_string); $table_array[1] } . _field_int =
   { my $right = $stack->get("result"); my %s=map{$_=>1} @$right; my @r=(keys %s); my $table_string = $prng->arrayElement(\@r); my @table_array = split(/AS/,
 $table_string); $table_array[1] } . _field_int_indexed
   { my $left = $stack->get("left");  my $right = $stack->get("result"); my @n = (); push(@n,@$right); push(@n,@$left); $stack->pop(\@n); return undef } |
   { my $left = $stack->get("left"); my %s=map{$_=>1} @$left; my @r=(keys %s); my $table_string = $prng->arrayElement(\@r); my @table_array = split(/AS/, $table_string); $table_array[1] } . _field_int =
   { my $right = $stack->get("result"); my %s=map{$_=>1} @$right; my @r=(keys %s); my $table_string = $prng->arrayElement(\@r); my @table_array = split(/AS/,
 $table_string); $table_array[1] } . _field_int
   { my $left = $stack->get("left");  my $right = $stack->get("result"); my @n = (); push(@n,@$right); push(@n,@$left); $stack->pop(\@n); return undef } ;

char_condition:
   { my $left = $stack->get("left"); my %s=map{$_=>1} @$left; my @r=(keys %s); my $table_string = $prng->arrayElement(\@r); my @table_array = split(/AS/, $table_string); $table_array[1] } . _field_char =
   { my $right = $stack->get("result"); my %s=map{$_=>1} @$right; my @r=(keys %s); my $table_string = $prng->arrayElement(\@r); my @table_array = split(/AS/, $table_string); $table_array[1] } . _field_char 
   { my $left = $stack->get("left");  my $right = $stack->get("result"); my @n = (); push(@n,@$right); push(@n,@$left); $stack->pop(\@n); return undef } |
   { my $left = $stack->get("left"); my %s=map{$_=>1} @$left; my @r=(keys %s); my $table_string = $prng->arrayElement(\@r); my @table_array = split(/AS/, $table_string); $table_array[1] } . _field_char_indexed  =
   { my $right = $stack->get("result"); my %s=map{$_=>1} @$right; my @r=(keys %s); my $table_string = $prng->arrayElement(\@r); my @table_array = split(/AS/, $table_string); $table_array[1] } . _field_char 
   { my $left = $stack->get("left");  my $right = $stack->get("result"); my @n = (); push(@n,@$right); push(@n,@$left); $stack->pop(\@n); return undef } |
   { my $left = $stack->get("left"); my %s=map{$_=>1} @$left; my @r=(keys %s); my $table_string = $prng->arrayElement(\@r); my @table_array = split(/AS/, $table_string); $table_array[1] } . _field_char =
   { my $right = $stack->get("result"); my %s=map{$_=>1} @$right; my @r=(keys %s); my $table_string = $prng->arrayElement(\@r); my @table_array = split(/AS/, $table_string); $table_array[1] } . _field_char_indexed 
   { my $left = $stack->get("left");  my $right = $stack->get("result"); my @n = (); push(@n,@$right); push(@n,@$left); $stack->pop(\@n); return undef } ;

where_list:
        where_item | where_item |
        ( where_list and_or where_item ) ;

where_item:
        existing_table_item . `pk` comparison_operator number  |
        existing_table_item . `pk` comparison_operator existing_table_item . _field_int  |
	existing_table_item . _field_int comparison_operator number  |
        existing_table_item . _field_int comparison_operator existing_table_item . _field_int |
        existing_table_item . _field_int IS not NULL |
        existing_table_item . _field_int not IN (number_list) |
        existing_table_item . _field_int  not BETWEEN number[invariant] AND ( number[invariant] + _digit ) |
	existing_table_item . _field_char comparison_operator char_value  |
        existing_table_item . _field_char comparison_operator existing_table_item . _field_char |
        existing_table_item . _field_char IS not NULL |
        existing_table_item . _field_char not IN (char_list) |
        existing_table_item . _field_char  not BETWEEN char_value[invariant] AND CONCAT(char_value[invariant], char_value) |
	existing_table_item . _field_char not LIKE CONCAT(char_value, '%') ;

number_list:
        _digit | _digit | number | number_list, number ;

char_list:
        _char | char_list, _char ;

char_value:
	_char | _char(2) | _char(3) ;

################################################################################
# YB: add missing tables referenced in the SELECT-list.                        #
################################################################################
join_missing_table_items:
    { my @x=(); while ($tables < $min_tables) { push @x, expand($rule_counters,$rule_invariants, "join_new_table_item"); } ; join("", @x) } ;

join_new_table_item:
################################################################################
# The "xxx" part doesn't matter because int_condition and char_condition only  #
# looks at the table alias name after "xxx AS " in the table string.           #
################################################################################
	{ $stack->push() }
        { $stack->push(); my $x = "xxx AS table".$prng->int(1,$tables); my @s=($x); $stack->pop(\@s); "" }
        { $stack->set("left",$stack->get("result")); }
	left_right outer JOIN new_table_item ON ( join_condition ) ;


################################################################################
# We ensure that a GROUP BY statement includes all nonaggregates.              #
# This helps to ensure the query is more useful in detecting real errors /     #
# that the query doesn't lend itself to variable result sets                   #
################################################################################
group_by_clause:
	{ $gby = (@nonaggregates > 0 and (@aggregates > 0 or $prng->int(1,3) == 1) ? " GROUP BY ".join (', ' , @nonaggregates ) : "" ) }  ;

optional_group_by:
        | | | | | | | | group_by_clause ;

having_clause:
	| | | |
	{ ($gby or @aggregates > 0)? "HAVING ".join("", expand($rule_counters,$rule_invariants, "having_list")) : "" } ;

having_list:
        having_item |
        having_item |
	(having_list and_or having_item)  ;

################################################################################
# NOTE:  It would be nice if we also had aggregates in the pool for HAVING 
#        clause items, but the code overhead isn't necessarily worth it in the 
#        portable grammar - we do test this more thoroughly in the regular 
#        version of the grammar
################################################################################

having_item:
	{ ($gby and @nonaggregates > 0 and (!@aggregates or $prng->int(1,3) == 1)) ? $prng->arrayElement(\@nonaggregates) : join("", expand($rule_counters,$rule_invariants, "new_aggregate_existing_table_item")) }
	comparison_operator number ;

################################################################################
# We use the total_order_by rule when using the LIMIT operator to ensure that  #
# we have a consistent result set - server1 and server2 should not differ      #
################################################################################

order_by_clause:
	| | | 
	ORDER BY total_order_by desc /*+javadb:postgres: NULLS FIRST*/ limit  |
	ORDER BY order_by_list /*+javadb:postgres: NULLS FIRST*/ ;

total_order_by:
	{ join(', ', map { "field".$_ } (1..$fields) ) };

order_by_list:
	order_by_item  |
	order_by_item  , order_by_list ;

order_by_item:
	existing_select_item desc ;

desc:
        ASC | | | | | DESC ; 

################################################################################
# We mix digit and _digit here.  We want to alter the possible values of LIMIT #
# To ensure we hit varying EXPLAIN plans, but the OFFSET can be smaller        #
################################################################################

limit:
	| | LIMIT limit_size | LIMIT limit_size OFFSET _digit;

################################################################################
# Recommend 8 table : 2 join for smaller queries, 6 : 2 for larger ones
################################################################################

table_or_join:
           new_table_item | new_table_item | new_table_item | new_table_item | new_table_item | 
           new_table_item | new_table_item | new_table_item | join | join ;

################################################################################
# We stack the probabilities regarding table size via how we create tables
# with the gendata config file (conf/optimizer/outer_join.zz)
# If for some reason, you ever decide to change this, it is also possible to
# stack probabilities by creating a @table_set array and simply listing
# certain tables more often.  It is less elegant and adaptable, but we document
# it here just in case.
# EX:  @table_set = ("A","A","A","A","B","C")
#      replace the $executors->[0]->tables() in the rule below with
#      \@table_set as well
#
#      see the nonaggregate_select_item rule
#      plus the initial query rule for examples
################################################################################


new_table_item:
# We use the "AS table" bit here so we can have unique aliases if we use the same table many times
       { $stack->push(); my $x = $prng->arrayElement($executors->[0]->tables())." AS table".++$tables;  my @s=($x); $stack->pop(\@s); $x } ;

agg_field_table_alias:
	{ my $n = $prng->arrayElement(\@table_alias_set); $min_tables = $n if $min_tables < $n; "table".$n };

existing_table_item:
	{ "table".$prng->int($t1,$tables) };

existing_select_item:
	{ "field".$prng->int(1,$fields) };

_digit:
    1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 |
    1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | _tinyint_unsigned ;

number:
    _digit | _digit | _digit | _digit | _digit |
    _digit | _digit | _digit | _digit | _digit |
    _digit | _digit | _digit | _digit | _digit |
    _digit | _digit | _digit | _digit | _digit ;

number_disabled_bug21758:
    4294967296 | -4294967296 | _bigint ;
 
and_or:
   AND | AND | { $need_eq ? "AND" : "OR" } ;

comparison_operator:
	= | > | < | <= | >= |
	= | > | < | <= | >= |
	!= | <> ;

aggregate:
	COUNT( distinct | SUM( distinct | MIN( distinct | MAX( distinct ;

literal_aggregate:
	COUNT(*) | COUNT(0) | SUM(1) ;

not:
	| | | NOT;

################################################################################
# YB: Add FULL
################################################################################
left_right:
	LEFT | LEFT | LEFT | RIGHT |
	LEFT | LEFT | LEFT | RIGHT |
	LEFT | LEFT | LEFT | RIGHT |
	{ $need_eq = 1; "" } FULL ;

outer:
	| | | | OUTER ;

################################################################################
# We define LIMIT_rows in this fashion as LIMIT values can differ depending on      #
# how large the LIMIT is - LIMIT 2 = LIMIT 9 != LIMIT 19                       #
################################################################################

limit_size:
    1 | 2 | 10 | 100 | 1000;

