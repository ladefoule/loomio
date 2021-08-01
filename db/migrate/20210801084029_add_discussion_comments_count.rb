class AddDiscussionCommentsCount < ActiveRecord::Migration[6.0]
    class Discussion < ActiveRecord::Base
          has_many :comments
    end
    def up
      add_column :discussions, :comments_count, :integer, :default => 0, :null => false
      Discussion.reset_column_information
      Discussion.all.each do |discussion|
          discussion.comments_count = discussion.comments.count
          discussion.save!
      end
    end
    def down
      remove_column :discussions, :comments_count
    end
  end