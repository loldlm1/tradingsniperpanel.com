ActiveAdmin.register User do
  permit_params :email, :password, :password_confirmation, :name, :role, :preferred_locale, :time_zone

  index do
    selectable_column
    id_column
    column :email
    column :name
    column :role
    column :preferred_locale
    column :created_at
    actions
  end

  filter :email
  filter :name
  filter :role
  filter :preferred_locale
  filter :created_at

  form do |f|
    f.inputs do
      f.input :email
      f.input :name
      f.input :role, as: :select, collection: User.roles.keys
      f.input :preferred_locale, as: :select, collection: I18n.available_locales.map(&:to_s)
      f.input :time_zone
      f.input :password
      f.input :password_confirmation
    end
    f.actions
  end
end
