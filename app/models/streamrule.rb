class Streamrule < ActiveRecord::Base
  belongs_to :stream

  validates_presence_of :stream_id
  validates_presence_of :rule_type
  validates_presence_of :value

  TYPE_MESSAGE = 1
  TYPE_HOST = 2
  TYPE_SEVERITY = 3
  TYPE_FACILITY = 4
  TYPE_TIMEFRAME = 5

  def self.get_types_for_select_options
    {
      "Message" => self::TYPE_MESSAGE,
      "Timeframe" => self::TYPE_TIMEFRAME,
      "Host" => self::TYPE_HOST,
      "Severity" => self::TYPE_SEVERITY,
      "Facility" => self::TYPE_FACILITY
    }
  end
  
  def to_condition
    case rule_type
    when TYPE_MESSAGE then
      return {:message => /#{Regexp.escape value}/}
    when TYPE_HOST then
      return {:host => value}
    when TYPE_SEVERITY then
      return {:level => value.to_i}
    when TYPE_FACILITY then
      return {:facility => value.to_i}
    when TYPE_TIMEFRAME then
      return {:timeframe => value}
    end
  end
end
