class CreateGdrivestrgFolders < ActiveRecord::Migration
  def change
    create_table :gdrivestrg_folders do |t|
      t.string :folder_name
      t.string :remote_id

      t.timestamps
    end
  end
end
