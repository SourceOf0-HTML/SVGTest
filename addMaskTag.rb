require "pathname"

source_dir = Pathname("source")
destination_dir = Pathname("destination")

Pathname.glob(source_dir.join("**/*")) do |source_path|
  # ファイルじゃないとき（ディレクトリーのとき）はスキップ
  next unless source_path.file?

  # source_dir から見た相対パス
  rel_path = source_path.relative_path_from source_dir

  # 保存先のパス
  destination_path = destination_dir.join(rel_path)

  # ディレクトリーを必要に応じて作成
  destination_path.dirname.mkpath

  # 書き出し
  destination_path.open "w" do |f|
  
    isSVG = false
    elementCount = 0
    elementStr = ""
    
    # 元ファイルの各行について繰り返し
    source_path.each_line do |line|
      
      # コメントアウトはスキップ
      next if (line.start_with?("<!--") && line.end_with?("-->\n"))
      
      unless isSVG
        # まだデータ本体まで辿り着いてない
        if line.start_with?("<svg") then
          # 本体発見
          f.puts line
          isSVG = true
        end
        # 終了
        next
      end
      
      if line.start_with?("</svg>") then
        f.puts line
        # 終了
        next
      end
      if line.include?("Mtarget") then
        # ターゲット用の属性を付与
        f.puts line.sub(">", " clip-path=\"url(#mask_target)\">")
      
      elsif line.include?("Mask") then
        f.puts line
        
        # マスク用データを初期化
        elementStr = "<clipPath id=\"mask_target\">\n"
        elementCount = 1
        #f.puts "[FOUND]"
        
      elsif elementCount > 0 then
        
        if line.start_with?("<path") then
          # マスク用データに格納しつつ出力
          elementStr += line
          f.puts line
          
        elsif line.start_with?("</") then
          if elementCount == 1 then
            # マスク該当箇所終端のためマスクを出力
            elementStr += "</clipPath>"
            f.puts elementStr
            elementCount = 0
            
            # 元データの終端を出力
            f.puts line
            #f.puts "[END]"
            
          else
            # マスク用データに格納しつつ出力
            elementStr += line
            f.puts line
            
            # 要素の階層を下げる
            elementCount -= 1
            #f.puts "[DOWN]"
          end
          
        elsif line.start_with?("<") then
          # マスク用データに格納しつつ出力
          elementStr += line
          f.puts line
          
          # 要素の階層を上げる
          elementCount += 1
          #f.puts "[ADD]"
        end

      else
        # そのまま出力
        f.puts line
      end
      
    end
  end
  
end
