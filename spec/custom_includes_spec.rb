require 'spec_helper'

ActiveRecord::Base.establish_connection(
  adapter: 'sqlite3',
  database: 'test_db'
)

ActiveRecord::Base.logger = Logger.new(STDOUT)

class CreateTestTable < ActiveRecord::Migration
  def change
    create_table :test_records do |t|
      t.string :name
      t.integer :special_id
    end
  end
end

CreateTestTable.migrate(:up) unless ActiveRecord::Base.connection.data_source_exists?('test_records')

class Special
  attr_accessor :id

  def initialize(id)
    @id = id
  end

  def ==(other)
    @id == other.id
  end
end

class BaseTestRecord < ActiveRecord::Base
  self.table_name = 'test_records'
  include CustomIncludes
end

class TestRecord < BaseTestRecord
  custom_belongs_to :special, :special_id, :id

  def self.special_custom_includes(ids)
    ids.map { |id| Special.new(id) }
  end
end

class TestRecordWithInvalidObjId < BaseTestRecord
  custom_belongs_to :special, :special_id, :fake_id

  def self.special_custom_includes(ids)
    ids.map { |id| Special.new(id) }
  end
end

describe CustomIncludes do
  around do |example|
    ActiveRecord::Base.transaction do
      example.run
      raise ActiveRecord::Rollback
    end
  end

  before do
    TestRecord.create!(name: 'name1', special_id: 1)
  end

  it 'raises a CustomIncludesError when the custom_includes method is not defined' do
    expect { BaseTestRecord.custom_includes(:special).load }.to raise_error(CustomIncludes::Error)
  end

  it 'raises a CustomIncludesError when the included object does not have the given identifier' do
    expect { TestRecordWithInvalidObjId.custom_includes(:special).load }.to raise_error(CustomIncludes::Error)
  end

  it 'raises a CustomIncludesError when the record does not have the given column' do
    expect do
      class TestRecordWithInvalidAttr < BaseTestRecord
        custom_belongs_to :special, :fake_column, :id

        def self.special_custom_includes(ids)
          ids.map { |id| Special.new(id) }
        end
      end
    end.to raise_error(CustomIncludes::Error)
  end

  it 'can be called on the Record object' do
    expect(TestRecord.custom_includes(:special).first.special).to eq(Special.new(1))
  end

  it 'can be chained with AR queries' do
    expect(TestRecord.where(id: 1).custom_includes(:special).first.special).to eq(Special.new(1))
  end

  it 're-runs custom includes on queries applied to loaded AR relations' do
    TestRecord.create!(name: 'name2', special_id: 2)

    records = TestRecord.where(id: [1, 2]).custom_includes(:special)
    records.load
    records = records.where(id: 1)

    expect(records.map { |r| r.special }).to contain_exactly(Special.new(1))
  end

  it 'raises a CustomIncludesError when a matching included object cannot be found for the record' do
    class TestRecordRequireMatches < BaseTestRecord
      custom_belongs_to :special, :special_id, :id

      def self.special_custom_includes(ids)
        [Special.new(1001), Special.new(1002)]
      end
    end

    expect { TestRecordRequireMatches.custom_includes(:special).load }.to raise_error(CustomIncludes::Error)
  end

  it 'works with no query results' do
    expect(TestRecord.where(id: 999).custom_includes(:special)).to be_empty
  end

  it 'works with many query results' do
    TestRecord.create!(name: 'name2', special_id: 2)
    TestRecord.create!(name: 'name3', special_id: 3)
    TestRecord.create!(name: 'name4', special_id: 4)

    expect(TestRecord.all.custom_includes(:special)).to contain_exactly(Special.new(1), Special.new(2), Special.new(3), Special.new(4))
  end
end
