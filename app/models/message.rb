class Message
  include MongoMapper::Document

  key :message, String
  key :date, String
  key :host, String
  key :level, Integer
  key :facility, Integer
  key :deleted, Boolean

  # GELF fields
  key :gelf, Boolean
  key :full_message, String
  key :type, Integer
  key :file, String
  key :line, Integer

  LIMIT = 100
  
  scope :not_deleted, :deleted => [false, nil]
  scope :by_blacklisted_terms, lambda { |terms, filtered = false|
    where((filtered ? :message.in : :message.nin) => terms.collect { |term| /#{Regexp.escape term}/})
  }
  scope :by_blacklist, lambda {|blacklist| by_blacklisted_terms(blacklist.all_terms, true)}
  scope :page, lambda {|number| skip(self.get_offset(number))}
  scope :default_scope, fields(:full_message => 0).not_deleted.limit(LIMIT).order("$natural DESC")

  def self.get_conditions_from_date(timeframe)
    conditions = {}
    re = /^(from (.+)){0,1}?(to (.+))$/
    re2 = /^(from (.+))$/
    
    if (matches = (re.match(timeframe) or re2.match(timeframe)))
    
      from = matches[2]
      to = matches[4]
      
      conditions.merge!('$gt' => Chronic::parse(from).to_i) unless from.blank?
      conditions.merge!('$lt' => Chronic::parse(to).to_i) unless to.blank?
    end
    
    return conditions
  end
  
  def self.all_of_blacklist id, page = 1
    page = 1 if page.blank?
    
    b = Blacklist.find(id)
    return by_blacklist(b).default_scope.page(page).all
  end

  def self.count_of_blacklist id
    b = Blacklist.find(id)
    return by_blacklist(b).count
  end

  def self.all_with_blacklist page = 1, limit = LIMIT
    page = 1 if page.blank?

    terms = Blacklist.all_terms
    by_blacklisted_terms(terms).default_scope.page(page)
  end

  def self.all_by_quickfilter filters, page = 1, limit = LIMIT, conditions_only = false
    page = 1 if page.blank?

    conditions = self

    unless filters.blank?
      # Message
      conditions = conditions.where(:message => /#{Regexp.escape(filters[:message].strip)}/) unless filters[:message].blank?

      # Time Frame
      conditions = conditions.where(:created_at => get_conditions_from_date(filters[:date])) unless filters[:date].blank?
      
      # Facility
      conditions = conditions.where(:facility => (filters[:facility].to_i == 42 ? nil : filters[:facility].to_i)) unless filters[:facility].blank?

      # Severity
      conditions = conditions.where(:level => filters[:severity].to_i) unless filters[:severity].blank?

      # Host
      conditions = conditions.where(:host => filters[:host]) unless filters[:host].blank?
    end
    
    conditions.default_scope.limit(LIMIT).page(page)
  end

  def self.by_stream(stream_id)
    s = Stream.find(stream_id)
    conditions = not_deleted
    s.streamrules.each do |rule|
      conditions = conditions.where(rule.to_condition)
    end
    
    conditions
  end

  def self.all_of_stream stream_id, page = 1, newer_than = nil
    page = 1 if page.blank?

    newer_than.nil? ? by_stream(stream_id).default_scope.page(page) : by_stream(stream_id).not_deleted.where(:created_at.gt => newer_than).order("$natural DESC")
  end

  def self.count_stream stream_id
    return by_stream(stream_id).count
  end

  def self.all_of_host host, page
    page = 1 if page.blank?

    where(:host => host).default_scope.page(page)
  end
  
  def self.all_of_hostgroup hostgroup, page
    page = 1 if page.blank?

    where(:host.in => hostgroup.get_hostnames).default_scope.page(page)
  end

  def self.count_of_host host
    where(:host => host).not_deleted.count
  end

  def self.count_of_hostgroup hostgroup
    where(:host.in => hostgroup.get_hostnames).not_deleted.count
  end

  def self.delete_all_of_host host
    self.delete_all :conditions => { :host => host, :deleted => false }
  end

  def self.count_since x
    conditions = not_deleted.where(:created_at.gt => x.to_i)
    conditions = conditions.by_blacklisted_terms(Blacklist.all_terms)
    
    conditions.count
  end

  def self.count_of_last_minutes x
    return self.count_since x.minutes.ago
  end

  def has_additional_fields
    return true if self.additional_fields.count > 0
    return false
  end
  
  def additional_fields
    additional = Array.new

    standard_fields = [ "created_at", "full_message", "line", "level", "_id", "deleted", "facility", "date", "type", "gelf", "file", "host", "message" ]

    self.keys.each do |key, value|
      next if standard_fields.include? key
      additional << { :key => key, :value => self[key] }
    end

    return additional
  end

  private

  def self.get_offset page
    if page.to_i <= 1
      return 0
    else
      return (LIMIT*(page.to_i-1))
    end
  end

end
