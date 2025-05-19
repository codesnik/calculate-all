## 0.4.0

* Add #async_calculate_all for rails > 7.1
* Drop support for ruby < 2.6, groupdate < 4

## 0.3.1

* Fix some arguments exceptions

## 0.3.0

* Allow expression shortcuts as attribute values too for renaming
* Allow grouping expressions to be returned in rows too
* Breaking change: only single *string* expression argument is returning unwrapped rows now.
  Single expression shortcut like `:count` will be expanded to `{count: value}` rows.

## 0.2.2

* Added support for Groupdate 4+ (Andrew <acekane1@gmail.com>)
* Tested with sqlite3, ruby 3.1, Rails 7

## 0.2.1

* Silence deprecation warnings (Forrest Ye <fye@mutan.io>)

## 0.2.0

* Rails 5 compatibility (Stef Schenkelaars <stef.schenkelaars@gmail.com>)

## 0.1.1

* groupdate compatibility
* Use passed block to process values

## 0.1.0

* First version
