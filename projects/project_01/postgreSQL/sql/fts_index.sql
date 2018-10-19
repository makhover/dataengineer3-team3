-- Добавляем поле с вектором
alter table item_details_full add fts tsvector;

-- Обновляем вектор
update item_details_full
set fts = 
	(setweight(to_tsvector('russian', title), 'A')||
	setweight(to_tsvector('russian', annotation), 'B')
	);

-- Создаем FTS индекс
CREATE INDEX idx_rum_fts ON item_details_full USING rum (fts rum_tsvector_ops);
 
--  Функция для удобства поиска
CREATE FUNCTION search_item(token varchar(300))
RETURNS TABLE(title varchar(300), annotation text) AS 
$$
	select 
		title, annotation
	from item_details_full f
	where fts @@ plainto_tsquery('russian',token)
	ORDER BY ts_rank_cd(fts, plainto_tsquery('russian',token)) DESC
	limit 5;
$$ 
LANGUAGE sql;

-- Проверка
select * from search_item('книги для детей 100 способов')




