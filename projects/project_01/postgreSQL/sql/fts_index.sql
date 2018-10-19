--Таблица для импорта json
create table items_import
(doc json);

--Импорт данные в таблицу с json
copy items_import(doc) from '/home/oleg_dobretsov/item_details_full.json' csv quote e'\x01' delimiter e'\x02';

-- Проверка
select count(*) from items_import;

-- Делаем таблицу с отдельными полями
CREATE TABLE item_details_full (
	"item_id" int4,
	"item_name" varchar(300),
    "annotation" TEXT
);

--Перегружаем в таблицу с отдельными полями
insert into item_details_full
	(item_id,
	item_name,
	annotation)
select 
	cast(doc::json->>'itemid' as int),
	doc::json->>'attr1',
	doc::json->>'attr0'
from items_import;
limit 10

-- Добавляем поле с вектором
alter table item_details_full add fts tsvector;

-- Обновляем вектор
update item_details_full
set fts = 
	(setweight(to_tsvector('russian', title), 'A')||
	setweight(to_tsvector('russian', annotation), 'B')
	);

-- Создаем FTS индекс (тип RUM - надо ставить отдельно черех менеджер пакетов)
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

