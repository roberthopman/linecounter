class Widget < ApplicationRecord
  # rev: 3
  include Searchable
  extend Findable

  STATUSES = %w[draft active archived].freeze

  belongs_to :account
  has_many :parts, dependent: :destroy
  has_one :manual

  validates :name, presence: true
  validate :name_not_reserved
  scope :active, -> { where(status: "active") }
  before_save :normalize_name
  enum status: { draft: 0, active: 1, archived: 2 }

  attr_reader :cached_total

  def self.build_default(account)
    new(account: account, name: "untitled")
  end

  def initialize(attrs = {})
    super
    @cached_total = 0
  end

  def display_name
    if name.present?
      name.titleize
    elsif draft?
      "Draft widget"
    else
      "Unnamed"
    end
  end

  def total
    parts.sum(&:price) || 0
  end

  private

  def normalize_name
    self.name = name.to_s.strip
  end

  def name_not_reserved
    return unless name == "admin"
    errors.add(:name, "is reserved")
  end
end
