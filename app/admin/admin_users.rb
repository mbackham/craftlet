ActiveAdmin.register AdminUser do
  menu parent: 'rbac_menu', priority: 5, label: proc { I18n.t('admin.labels.admin_users') }, if: proc { current_admin_user.admin? }

  permit_params :email, :password, :password_confirmation, :role, admin_role_ids: []

  # 编辑用户时如果密码留空，则不更新密码（Devise + ActiveAdmin 经典处理）
  # 同时绕过 PunditAdapter 的参数过滤，避免 admin_role_ids 被拒绝
  controller do
    def update
      @admin_user = AdminUser.find(params[:id])

      # 手动处理参数，绕过 Pundit 参数过滤
      attrs = params.require(:admin_user).permit(
        :email, :role, :password, :password_confirmation, admin_role_ids: []
      )

      # 密码留空时移除密码参数
      if attrs[:password].blank?
        attrs.delete(:password)
        attrs.delete(:password_confirmation)
      end

      if @admin_user.update(attrs)
        redirect_to resource_path(@admin_user), notice: "管理员已更新"
      else
        render :edit
      end
    end

    def create
      attrs = params.require(:admin_user).permit(
        :email, :role, :password, :password_confirmation, admin_role_ids: []
      )
      @admin_user = AdminUser.new(attrs)

      if @admin_user.save
        redirect_to resource_path(@admin_user), notice: "管理员已创建"
      else
        render :new
      end
    end
  end

  index do
    selectable_column
    id_column
    column :email
    column :role
    column("管理角色") do |user|
      user.admin_roles.map(&:name).join("、").presence || "-"
    end
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

  show do
    attributes_table do
      row :id
      row :email
      row :role
      row("管理角色") do |user|
        user.admin_roles.map { |r| "#{r.name} (#{r.code})" }.join("、").presence || "无"
      end
      row :sign_in_count
      row :current_sign_in_at
      row :last_sign_in_at
      row :current_sign_in_ip
      row :last_sign_in_ip
      row :failed_attempts
      row(:locked_at) { |u| u.locked_at || "未锁定" }
      row :created_at
      row :updated_at
    end

    panel "分配的权限（来自管理角色）" do
      permissions = AdminPermission.joins(admin_roles: :admin_user_roles)
                                   .where(admin_user_roles: { user_id: resource.id })
                                   .distinct.order(:code)
      if permissions.any?
        table_for permissions do
          column(:code) { |p| content_tag(:code, p.code) }
          column(:name) { |p| p.name }
        end
      else
        if resource.admin?
          para "超级管理员拥有全部权限", style: "color: #16a34a; font-weight: bold;"
        else
          para "无任何权限（请分配管理角色）", style: "color: #dc2626;"
        end
      end
    end
  end

  form do |f|
    f.inputs "账号信息" do
      f.input :email
      f.input :role, as: :select, collection: AdminUser.roles.keys, include_blank: false,
              hint: "admin = 超级管理员（拥有全部权限），operator = 普通管理员（权限由下方角色决定）"
      f.input :password, hint: "至少12位，需包含大写、小写、数字和特殊字符"
      f.input :password_confirmation
    end

    f.inputs "管理角色（仅 operator 需要分配）" do
      f.input :admin_roles,
              as: :check_boxes,
              collection: AdminRole.all.order(:name),
              label_method: -> (r) { "#{r.name} (#{r.code})" }
    end

    f.actions
  end

end
