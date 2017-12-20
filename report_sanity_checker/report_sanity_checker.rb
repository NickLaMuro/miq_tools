#!/usr/bin/env ruby

# currently, running this from miq root directory
#require File.expand_path('config/environment', __dir__)
require File.expand_path('config/environment', Dir.pwd)

require_relative 'table'

# monkey patch required for earlier versions
if !MiqReport.method_defined?(:menu_name=)
  class MiqReport
    alias_attribute :menu_name, :name
  end
end

#if !MiqExpression.method_defined?(:fields)
MiqExpression
class MiqExpression
  def fields(expression = exp)
    case expression
    when Array
      expression.flat_map { |x| fields(x) }
    when Hash
      return [] if expression.empty?

      if (val = expression["field"] || expression["count"] || expression[""])
        ret = []
        v = self.class.parse_field_or_tag(val)
        ret << v if v
        v = self.class.parse_field_or_tag(expression["value"].to_s)
        ret << v if v
        ret
      else
        fields(expression.values)
      end
    end
  end
end
#end

if !MiqExpression::Field.method_defined?(:virtual_reflection?)
  class MiqExpression::Field
    def virtual_attribute?
      target.virtual_attribute?(column)
    end

    def virtual_reflection?
      associations.present? && (model.follow_associations_with_virtual(associations) != model.follow_associations(associations))
    end
    # old version doesn't include virtual_reflection?
    def attribute_supported_by_sql?
      !custom_attribute_column? && target.attribute_supported_by_sql?(column) && !virtual_reflection?
    end

    def collect_reflections
      klass = model
      associations.collect do |name|
        reflection = klass.reflect_on_association(name)
        if reflection.nil?
          if klass.reflection_with_virtual(name)
            break
          else
            raise ArgumentError, "One or more associations are invalid: #{association_names.join(", ")}"
          end
        end
        klass = reflection.klass
        reflection
      end
    end

    def collect_reflections_with_virtual(association_names)
      klass = model
      associations.collect do |name|
        reflection = klass.reflection_with_virtual(name) ||
                     raise(ArgumentError, "One or more associations are invalid: #{associations.join(", ")}")
        klass = reflection.klass
        reflection
      end
    end
  end
end

class ReportSanityChecker
  attr_accessor :pattern
  attr_accessor :verbose

  def initialize
    @verbose = true
  end

  def parse(args)
    # was: /#{args[0]}/i if args[0]
    # currently can be a filename, or a pattern. the pattern is assumed to be living in product/views,reports
    # Note: views and reports are now in separate repos (manageiq and manageiq-ui-classic)
    @pattern = args[0]
    self
  end

  def filenames
    if pattern
      if Dir.exist?(pattern)
        self.pattern = "#{pattern}/" unless pattern.ends_with?("/")
        Dir["#{pattern}**/*.{yaml,yml}"]
      elsif File.exist?(pattern)
        Dir[pattern]
      else
        pattern_re = /#{pattern}/i
        Dir["product/{views,reports}/**/*.{yaml,yml}"].select { |f| f =~ pattern_re }
      end
    else
      Dir["product/{views,reports}/**/*.{yaml,yml}"]
    end
  end

  def parse_file(filename)
    filename.kind_of?(MiqReport) ? filename : MiqReport.new(YAML.load_file(filename))
  end

  def guess_class(filename)
    filename.split("/").last.split(".").first.split("-").first.gsub("_","::").split("__").first
  end

  def check_report(filename)
    rpt = parse_file(filename)

    includes_cols = includes_to_cols(rpt.db, rpt.include)

    klass = rpt.db_class rescue nil

    tbl = Table.new
    # make sure there is enough room for all columns
    tbl.pad(0, rpt.col_order)
    tbl.pad(0, rpt.cols)
    tbl.pad(0, flds_to_strs(includes_cols))
    tbl.pad(1, %w(association virtual db))
    tbl.hide(1)
    tbl.pad(2, %w(virtual custom db unknown))
    tbl.format(2)
    tbl.pad(3, %w(sql ruby))
    # TODO: this attribute may be from another model, so klass is probably wrong here
    tbl.format(3)
    tbl.pad(4, %w(both col includes missing))
    tbl.format(4)
    tbl.hide(4)
    tbl.pad(5, %w(alias))
    tbl.format(5)
    tbl.hide(5)
    tbl.pad(6, %w(sort))
    tbl.format(6)
    tbl.pad(7, %w(hidden sql_only include sort_only))
    tbl.format(7)
    #tbl.hide(7) # typically want this, but for now, hiding it
    tbl.pad(8, %w(cond))
    tbl.format(8)
    if verbose
      begin
        if filename.kind_of?(MiqReport)
          #puts "", "#{rpt.name}:", ""
        else
          name = filename
          name << " (#{rpt.db})" if rpt.db != guess_class(filename)

          puts "","#{name}:",""
        end

        rpt.db_class # ensure this can be run
        tbl.print_hdr("column", "relation", "virtual", "sql", "src", "alias", "sort", "hidden", "cond")
        tbl.print_dash
        print_details(tbl, rpt)
      rescue NameError
        puts "unknown class defined in ':db' field: #{rpt.db}"
      end
    else # punted (havent updated this in a while)
      sf = short_padded_filename(filename, 30)
      if rpt.col_order.sort == (rpt.cols + includes_cols).sort
        # this probably belongs in the summary
        puts "#{sf}: col_order = rpt.cols #{"+ rpt.include" && includes_cols.present?}" if verbose
      else
        puts "#{sf}:"
      end
      print_summary(rpt)
    end
  end

  def self.run(argv = ARGV)
    checker = new.parse(argv)
    puts "running #{checker.filenames.size} reports"
    checker.filenames.each { |f| checker.check_report(f) }.size
  end

  def self.run_widgets

  end

  private

  # convert "includes" recursive hash to columns
  # only paying attention to "columns" and "includes" - hence the noteable_includes method
  # TODO: know when it is a virtual association
  def includes_to_cols(model, h, associations = [])
    return [] if h.blank?
    h.flat_map do |table, table_hash|
      next_associations = associations + [table]
      (table_hash["columns"] || []).map { |col| MiqExpression::Field.new(model, next_associations, col) } +
        includes_to_cols(model, table_hash["includes"], next_associations)
    end
  end

  def includes_to_tables(h, associations = [])
    ret = {}
    return ret if h.blank?
    h.each do |table, table_hash|
      includes_to_cols(table_hash["includes"], ret[table.to_sym] = {})
    end
    ret
  end

  # a, b, c

  # in primary, but not in extras
  def subtract_hash(primary, extras)
    return primary unless primary.present? && extras.present?
    primary.each_with_object({}) do |(n, v), h|
      if extras[n]
        v2 = subtract_hash(v, extras[n])
        h[n] = v2 if v2.present?
      else
        h[n] = v
      end
    end
  end

  def union_hash(primary, extras)
    return {} unless primary.present? && extras.present?
    primary.each_with_object({}) do |(n, v), h|
      if extras[n]
        h[n] = union_hash(v, extras[n])
      end
    end
  end

  def strs_to_fields(model, associations, cols)
    cols.map { |col| MiqExpression::Field.new(model, associations, col) }
  end

  def flds_to_strs(flds)
    flds.map { |f| (f.associations + [f.column]).join(".") }
  end

  # # any includes that look funny?
  # def noteable_includes?(h)
  #   return false if h.blank?
  #   h.each do |table, table_hash|
  #     return true if (table_hash.keys - %w(includes columns)).present?
  #     return true if noteable_includes?(table_hash["includes"])
  #   end
  #   false
  # end

  # reports are typically in product/view/*.yml, this abbreviates that name, and padds to the left
  def short_padded_filename(filename, filenamesize)
    sf = filename.split("/")
    # shorten product/view/rpt.yml text - otherwise, just use the name
    sf = sf.size < 2 ? sf.last : "#{sf[1][0]}/#{sf[2..-1].join("/")}"
    if sf.size > filenamesize
      sf + "\n" + "".ljust(filenamesize)
    else
      sf.ljust(filenamesize)
    end
  end

  SP = (" " * 30).freeze

  # currently punted
  def print_summary(rpt)
    sp = SP
    # columns defined via includes / (joins)  
    includes_cols = flds_to_strs(includes_to_cols(rpt.db, rpt.include))

    # NEEDED
    # a header corresponds to each col_order
    headers_match = rpt.col_order.size == rpt.headers.size # may want to make a smarter match than size
    # are there extra attribtues in includes hash we were not expecting
    # luckily there are none of these
    # n_includes = noteable_includes?(rpt.include)

    #?
    cols_alias = rpt.cols.select { |c| c.include?(".") }
    # are there columns in the col_order that are not in sql OR includes?
    # luckily there are none of these
    extra_col_order = rpt.col_order - rpt.cols - includes_cols
    # cols brought back in sql but not displayed (in col_order)
    extra_cols = rpt.cols - rpt.col_order
    # cols brought back via includes, but not displayed (in col_order)
    extra_includes = includes_cols - rpt.col_order

    puts "#{sp}: extra col_order : #{extra_col_order.inspect}" if extra_col_order.present?
    puts "#{sp}: extra cols      : #{extra_cols.inspect}" if extra_cols.present?
    puts "#{sp}: cols_alias      : #{cols_alias.inspect}" if cols_alias.present?
    puts "#{sp}: includes  : #{rpt.include.inspect}" if extra_includes.present? # || n_includes
    puts "#{sp}: headers mismatch" unless headers_match
  end

  def print_details(tbl, rpt)
    include_for_find = rpt.include_for_find || {}
    includes_cols = Set.new(flds_to_strs(includes_to_cols(rpt.db, rpt.include)))

    includes_tbls = rpt.try(:include_as_hash) || rpt.include && includes_to_tables(rpt.include) # || fallback
    includes_tbls = rpt.invent_includes if rpt.respond_to?(:invent_includes) && rpt.include.blank? # removed from yaml file
    includes_tbls ||= {}

    # byebug if rpt.respond_to?(:invent_includes) && rpt.include && (rpt.invent_includes != includes_tbls)

    full_includes = includes_tbls.deep_merge(include_for_find)


    # columns defined via includes / (joins)  
    rpt_cols = Set.new(rpt.cols)
    sort_cols = Set.new(Array.wrap(rpt.sortby))
    if (miq_cols = rpt.conditions.try(:fields))
      # use fully qualified field names
      miq_col_names = Set.new(miq_cols.map { |c| ((c.associations||[]) + [c.column]).compact.join(".") })
      #miq_cols = miq_cols.index_by { |c| c.column }
    else
      miq_col_names = Set.new
    end

    # do we want to convert a column into a field?

    # --
    klass = rpt.db_class
    rpt.col_order.each do |col|
      # are there columns in the col_order that are not in sql OR includes?
      # luckily there are none of these
      # --> inline
      in_rpt  = rpt_cols.include?(col)
      in_inc  = includes_cols.include?(col)
      in_col  = rpt.col_order.include?(col) ? ""     : "hidden" # true
      in_sort = sort_cols.include?(col)     ? "sort" : ""
      in_miq  = miq_col_names.include?(col) ? "cond" : ""
      print_row(tbl, klass, col, in_rpt, in_inc, in_sort, in_col, in_miq)
    end

    # cols brought back in sql but not displayed (present in col_order)
    # they may be used by custom ui logic or a ruby virtual attribute
    # typically this field is unneeded and can be removed
    (rpt_cols - rpt.col_order).each do |col|
      in_rpt  = rpt_cols.include?(col)
      in_inc  = includes_cols.include?(col) # probably always false
      in_col  = rpt.col_order.include?(col) ? ""     : "sql only" # false
      in_sort = sort_cols.include?(col)     ? "sort" : ""
      in_miq  = miq_col_names.include?(col) ? "cond" : ""
      print_row(tbl, klass, col, in_rpt, in_inc, in_sort, in_col, in_miq)
    end
    # cols brought back via includes, but not displayed (present in col_order)
    # the field may be used by custom ui logic or a ruby virtual attribute
    # do note, this was based upon the assumption that all includes could be derived from column names
    # this was rolled back - so this may not be completely relevant
    (includes_cols - rpt.col_order).each do |col|
      in_rpt  = rpt_cols.include?(col)
      in_inc  = includes_cols.include?(col) # true by definition
      in_col  = rpt.col_order.include?(col) ? ""     : "include" # false
      in_sort = sort_cols.include?(col)     ? "sort" : ""
      in_miq  = miq_col_names.include?(col) ? "cond" : ""
      print_row(tbl, klass, col, in_rpt, in_inc, in_sort, in_col, in_miq)
    end
    # cols in in_sort, but not defined (and not displayed)
    # Pretty sure the ui ignores this column
    # TODO: not sure what we should highlight here
    (sort_cols - rpt.col_order - includes_cols - rpt_cols).each do |col|
      in_rpt  = rpt_cols.include?(col)
      in_inc  = includes_cols.include?(col)
      in_col  = rpt.col_order.include?(col) ? ""     : "sort only" # false
      in_sort = sort_cols.include?(col)     ? "sort" : ""
      in_miq  = miq_col_names.include?(col) ? "cond" : ""
      print_row(tbl, klass, col, in_rpt, in_inc, in_sort, in_col, in_miq)
    end

    # for these: need to convert reports to using Field vs target....
    (miq_col_names - rpt.col_order - includes_cols - rpt_cols).each do |col|
      in_rpt  = rpt_cols.include?(col)
      in_inc  = includes_cols.include?(col)
      in_col  = rpt.col_order.include?(col) ? ""     : "cond only"
      in_sort = sort_cols.include?(col)     ? "sort" : ""
      in_miq  = miq_col_names.include?(col) ? "cond" : "" # true
      print_row(tbl, klass, col, in_rpt, in_inc, in_sort, in_col, in_miq)
    end

    #puts "includes: #{includes_tbls.inspect}" if includes_tbls.present?
    puts
    # this may be going on the asumption that we are removing include when it can be discovered
    # in the sort_order.
    # see https://github.com/ManageIQ/manageiq/pull/13675
    # see last message of https://github.com/ManageIQ/manageiq/pull/13675 (include changes were reverted)
    puts "extra includes: #{include_for_find.inspect}" if include_for_find.present?
    unneeded_iff = union_hash(includes_tbls, include_for_find)
    puts "unneeded includes_for_find: #{unneeded_iff.inspect}" if unneeded_iff.present?
  end
  
  def print_row(tbl, klass, col, in_rpt, in_inc, in_sort, in_col, in_miq)
    *class_names, col_name = [klass.name] + col.split(".")
    field_name = "#{class_names.join(".")}-#{col_name}"

    f = MiqExpression.parse_field_or_tag(field_name)
    is_alias = col.include?(".") ? "alias" : nil
    col_src = in_rpt ? (in_inc ? "both" : "col") : (in_inc ? "includes" : "missing")

    STDERR.puts "problem houston: #{klass}...#{col} (#{field_name})" if f.nil?

    # 1
    vr = nil
      # if f.kind_of?(MiqExpression::Tag)
      #   "custom"
      # elsif f.associations.blank?
      #   "" # "direct"
      # elsif f.virtual_reflection?
      #   "virtual"
      # else
      #   "db"
      # end
    # 2
      va = 
        if f.kind_of?(MiqExpression::Tag)
          "custom"
        elsif f.virtual_reflection?
          "join"
        elsif f.virtual_attribute? #klass && klass.virtual_attribute?(col)
          "attr"
        else
          if klass && (f.target.has_attribute?(f.column) || f.target.try(:attribute_alias?, f.column))
            # these are both good - no reason to call them out
            "" # f.associations.present? ? "join" : "db"
          else
            "unknown"
          end
        end

    # 3
    # tags don't have attribute_supported_by_sql?
    sql_support = klass ? f.try(:attribute_supported_by_sql?) ? "sql" : "ruby" : "?"

    tbl.print_col(col, vr, va, sql_support, col_src, is_alias, in_sort, in_col, in_miq)
  end
end

class WidgetSanityChecker
  def filenames
    Dir.glob("product/dashboard/widgets/*")
  end

  def widget_and_report_names
    filenames.map do |filename|
      yaml = YAML.load(IO.read(filename))
      if yaml["resource_type"] != "MiqReport"
        puts "skipping #{filename}:: #{yaml["resource_type"]}"
        #next([])
        nil
      else
        resource_name = yaml["resource_name"]
        [filename, yaml, resource_name]
      end
    end.compact
  end

  def run
    checker = ReportSanityChecker.new
    widget_and_report_names.each do |widget, widget_yaml, rpt_name|
      # could have loaded the yaml file with the report name, but this is easier
      rpt = MiqReport.find_by(name: rpt_name)
      puts "", "# WIDGET: #{widget}"
# skipping timezone saves a lot of performance time
# options:
#   :timezone_matters: false
      puts "# TIMEZONE MATTERS: #{widget_yaml["options"][:timezone_matters]}" if widget_yaml["options"].try(:key?, :timezone_matters)
      puts "# REPORT: #{rpt_name}", ""
      if rpt
        checker.check_report(rpt)
      else
        puts "ERROR: Couldn't find #{rpt_name}"
      end
    end.size
  end

  def self.run(argv = ARGV)
    new.run
  end
end

#if __FILE__ == $0
if ARGV.include?("-w")
  WidgetSanityChecker.run(ARGV)
else
  ReportSanityChecker.run(ARGV)
end
#end
