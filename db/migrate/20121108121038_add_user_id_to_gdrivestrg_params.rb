class AddUserIdToGdrivestrgParams < ActiveRecord::Migration
  def change
    add_column :gdrivestrg_params, "#{Gdrivestrg.user_class.downcase}_id".to_sym, :integer
  end
end
