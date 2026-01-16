ActiveAdmin.register RevenueSplitRule do
  permit_params :effective_at, :us_percent, :client_percent, :note

  index do
    selectable_column
    id_column
    column :effective_at
    column :us_percent
    column :client_percent
    column :note
    column :created_at
    actions
  end

  filter :effective_at
  filter :created_at

  form do |f|
    f.inputs do
      f.input :effective_at
      f.input :us_percent
      f.input :client_percent
      f.input :note
    end
    f.actions
  end
end
