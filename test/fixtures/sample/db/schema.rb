ActiveRecord::Schema.define(version: 2024_01_01_000000) do
  create_table :widgets do |t|
    t.string :name
    t.integer :status
    t.references :account
    t.timestamps
  end
end
