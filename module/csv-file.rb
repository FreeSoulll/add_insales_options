module CSVFile
  def read_csv(input_file, output_file)
    @all_modifications = {}
    data = CSV.read(input_file, headers: true, col_sep: ',', encoding: 'utf-8')

    # Поиск всех уникальных заголовков модификаций
    modification_headers = data.flat_map do |row|
      if (modifications = row['Modifications'])
        modifications.split('|').map { |mod| "Опция: #{mod.split(':').first.strip}" }
      elsif (modifications = row['Editions'])
        modifications.split('///').map { |mod| "Свойство: #{mod.split(':').first.strip}" }
      else
        []
      end
    end.uniq

    # Добавляем найденные заголовки к списку заголовков изначального файла
    new_headers = data.headers.to_a + modification_headers

    # Обрабатываем данные и формируем новую таблицу
    CSV.open(output_file, 'w', write_headers: true, headers: new_headers) do |csv|
      data.each do |row|
        new_row = row.to_h

        modification_headers.each { |header| new_row[header] = nil }

        # Если модификации существуют, обрабатываем их
        if (modifications = row['Modifications'])
          modifications.split('|').each do |modification|
            title, options = modification.split(':', 2)
            next unless title && options

            title.strip!

            first_option = options
            selected_value = first_option if first_option

            @product_options << { title: row['Title'], options: [title] } if @product_options.empty?

            product = @product_options.find{ |hash| hash[:title] == row['Title'] }

            if product
              product[:options] << title unless product[:options].include?(title)
            else
              @product_options << { title: row['Title'], options: [title] }
            end

            # Записываем в инстанс все опции, чтобы потом можно было добавить их по апи
            @all_modifications[title] = selected_value
            # Устанавливаем значение в соответствующую колонку
            new_row["Опция: #{title}"] = selected_value
          end
        elsif (modifications = row['Editions'])
          modifications.split('///').each do |modification|
            title, options = modification.split(':', 2)
            next unless title && options

            title.strip!

            first_option = options
            selected_value = first_option if first_option

            # Устанавливаем значение в соответствующую колонку
            new_row["Свойство: #{title}"] = selected_value
          end
        end

        csv << new_row.values_at(*new_headers)
      end
    end
  end
end