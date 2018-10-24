# Организация полнотекстового поиска в Postgre SQL

## Подготовка
#### Создаем базу
```bash
createdb retail_db;
```
#### Подключаемся к Postgres
```bash
psql retail_db;
```

## Загрузка данных
#### Создаем временную таблицу для загрузки файла в JSON "AS IS"

```sql
create table items_import
(doc json);
```

#### Загружаем данные в таблицу (bulk-load) через функцию COPY

```sql
copy items_import(doc) from '/home/oleg_dobretsov/item_details_full.json' csv quote e'\x01' delimiter e'\x02';

COPY 9273625
Time: 378855.646 ms (06:18.856)
```

Проверяем данные
```sql
select count(*) from items_import;

  count  
---------
 9273625
(1 row)

Time: 73845.707 ms (01:13.846)
```

#### Создаем целевую таблицу с разобранными полями
```sql
CREATE TABLE items (
    "item_id" int4,
    "title" varchar(300),
    "annotation" text
);
```
#### Загружаем данные в целевую таблицу
```sql
insert into items
	(item_id,
	title,
	annotation)
select 
	cast(doc::json->>'itemid' as int),
	doc::json->>'attr1',
	doc::json->>'attr0'
from items_import;

INSERT 0 9273625
Time: 309291.960 ms (05:09.292)

```

## Строим полнотекстовый индекс
#### Добавляем поле для хранения вектора (массив нормализованных слов)
```sql
alter table items add fts tsvector;
```
#### Обновляем вектор (по названию и описанию)
```sql
update items
set fts = 
	(setweight(to_tsvector('russian', title), 'A')||
	setweight(to_tsvector('russian', annotation), 'B')
	);

UPDATE 9273625
Time: 1346292.160 ms (22:26.292)    
```
#### Строим индекс по полю с вектором
Используем тип индекса RUM - его надо поставить отдельно через менеджер пакетов
```sql
CREATE EXTENSION rum;
CREATE INDEX idx_rum_fts ON items USING rum (fts rum_tsvector_ops);

Время содания - примерно 1.5 - 2 часа

```
#### Создаем функцию для удобства поиска
```sql
CREATE or REPLACE FUNCTION search_item(token varchar(300))
RETURNS TABLE(title varchar(300), annotation text) AS 
$$
	select 
		title, annotation
	from items f
	where fts @@ plainto_tsquery('russian',token)
	ORDER BY ts_rank_cd(fts, plainto_tsquery('russian',token)) DESC
	limit 5;
$$ 
LANGUAGE sql;
```

## 3. Проверяем поиск на примерах
```sql
select * from search_item('книги для детей 100 способов');
Time: 34.523 ms

select * from search_item('Дон Кихот');
Time: 24.778 ms

select * from search_item('Война и мир');
Time: 335.976 ms

select * from search_item('Преступление и наказание');
Time: 21.808 ms

select * from search_item('Графиня де Монсоро');
Time: 507.466 ms
```

## Настраиваем  HTTP
###  Ставим пакет [PostgREST](https://github.com/PostgREST/postgrest)

```bash
wget https://github.com/PostgREST/postgrest/releases/download/v5.1.0/postgrest-v5.1.0-ubuntu.tar.xz
sudo apt install xz-utils
tar -zxf postgrest-v5.1.0-ubuntu.tar.xz
```

####  Настраиваем конфиг
```bash
nano ~/postgrest_items.conf

db-uri = "postgres://$USER:$PASSWORD@1$HOST/$DB"
db-schema = "public"
db-anon-role = "$USER"
server-host = "0.0.0.0"
```
#### Запускаем RestAPI
```bash
./postgrest postgrest_items.conf

Listening on port 3000
Attempting to connect to the database...
Connection successful
```

#### Проверяем локально
```bash
curl localhost:3000?rpc/search_item?token='Детские'
```

## Создаем страницу поиска
Кладем в /var/www/dataengineer/search страницу index.html
```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Search demo site</title>
</head>
<body>
<h1>Elasticsearch client side demo</h1>
<div id="search_container">
    <label for"search">Search</label>
    <input type="text" id="search"/>
    <input type="submit" onclick="doSearch(document.getElementById('search').value);"/>
</div>
<div id="total"></div>
<div id="hits"></div>
<script type="application/javascript">
  function doSearch (needle) {
    //var searchHost = 'http://35.240.65.74:9010/query';
    if (needle.length !== 0) {
        var searchLink = 'http://35.240.65.74:3000/rpc/search_item?token='+encodeURIComponent(needle)+'&limit=5';
      }
    else {
        var searchLink = 'http://35.240.65.74:3000/items?select=title,annotation&limit=5';
    }

    var xmlHttp = new XMLHttpRequest();
    xmlHttp.open('GET', searchLink, false);
    //xmlHttp.setRequestHeader('Content-Type', 'application/json;charset=UTF-8');
    //var url = JSON.stringify(query)
    //alert(url)
    //xmlHttp.send(url);
    xmlHttp.send();
    var response = JSON.parse(xmlHttp.responseText);

    // Print results on screen.
    var output = '';
    var output = '';
    for (var i = 0; i < response.length; i++) {
       output += '<h3>' + response[i].name + '</h3>';
       output += response[i].annotation + '</br>';
     }
     document.getElementById('total').innerHTML = '<h2>Showing ' + response.length + ' results</h2>';
     document.getElementById('hits').innerHTML = output;
  };
</script>
</body>
</html>
```

 **Запускаем!**
