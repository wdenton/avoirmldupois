class Channel < ActiveRecord::Base

  has_many :features, :dependent => :destroy

end
