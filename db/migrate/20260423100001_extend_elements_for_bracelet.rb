# frozen_string_literal: true

class ExtendElementsForBracelet < ActiveRecord::Migration[7.1]
  def change
    change_table :elements, bulk: true do |t|
      # 元素类型：区分珠子、绳子和其他素材
      t.string :element_type, default: 'other'

      # 材质：wood(木质)、glass(玻璃)、hetian_jade(和田玉)、jadeite(翡翠)、
      #        agate(玛瑙)、crystal(水晶)、amber(琥珀)、coral(珊瑚)、
      #        lapis(青金石)、turquoise(绿松石)、obsidian(黑曜石)、
      #        bodhi(菩提)、bone(骨质)、metal(金属)、ceramic(陶瓷)、
      #        resin(树脂)、fabric(布料) — 绳子材质、other(其他)
      t.string :material_type

      # 工艺/表面处理：matte(哑光)、glossy(亮光)、frosted(磨砂)、carved(雕刻)、polished(抛光)
      t.string :finish_type

      # 颜色
      t.string :color_hex     # 十六进制颜色值，如 #8B4513
      t.string :color_name    # 颜色名称，如"棕色"、"碧绿"

      # 尺寸与物理属性
      t.decimal :size_mm, precision: 6, scale: 2   # 珠子直径（毫米），绳子线径
      t.decimal :weight_g, precision: 8, scale: 3  # 单颗/单米重量（克）

      # 天然/仿制标识，用于标注珠子是天然石还是人工仿品
      t.boolean :is_natural, default: false

      # 产地/来源，如"缅甸翡翠"、"新疆和田"
      t.string :origin_region

      # 3D 展示资源
      t.string :mesh_url   # 3D 模型公开 URL（CDN 直链）
      t.string :glb_key    # GLB/GLTF 格式 3D 模型的 OSS Key

      # 颗粒度扩展：用于标注适用手腕围、推荐孔径等
      t.decimal :hole_diameter_mm, precision: 5, scale: 2  # 孔径（毫米）
      t.string  :hardness_level  # 硬度等级，如"莫氏7级"

      # 标签：自由标注，如 ["开运", "辟邪", "母亲节"]
      t.jsonb :tags, default: []

      # 预留扩展字段：存放未来新增的结构化属性，如 { "lustre": "oil", "clarity": "A级" }
      t.jsonb :metadata, default: {}
    end

    add_index :elements, :element_type
    add_index :elements, :material_type
    add_index :elements, :color_hex
    add_index :elements, :is_natural
    add_index :elements, :tags, using: :gin
    add_index :elements, :metadata, using: :gin
  end
end
