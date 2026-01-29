ActiveAdmin.register AdminUser do
  menu parent: proc { I18n.t('admin.menu.rbac') }, priority: 5, label: proc { I18n.t('admin.labels.admin_users') }

  permit_params :email, :password, :password_confirmation, :role

  index do
    selectable_column
    id_column
    column :email
    column :role
    column :current_sign_in_at
    column :sign_in_count
    column :created_at
    actions name: I18n.t('admin.columns.actions')
  end

  filter :email
  filter :role, as: :select, collection: AdminUser.roles.keys
  filter :current_sign_in_at
  filter :sign_in_count
  filter :created_at

  form do |f|
    f.inputs do
      f.input :email
      f.input :role, as: :select, collection: AdminUser.roles.keys, include_blank: false
      f.input :password
      f.input :password_confirmation
    end
    f.actions
  end

end
