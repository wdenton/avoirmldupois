class CreateChannels < ActiveRecord::Migration

  def up
    create_table :channels do |t|
      t.string :name, :null => false
    end
  end

  def down
    drop_table :channels
  end

end
