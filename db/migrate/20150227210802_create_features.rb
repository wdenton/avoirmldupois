class CreateFeatures < ActiveRecord::Migration

  def up
    create_table :features do |t|
      t.references :channel
      t.string     :name, :null => false
      t.string     :description
      t.float      :latitude,  :null => false
      t.float      :longitude, :null => false
    end
  end

  def down
    drop_table :features
  end

end
