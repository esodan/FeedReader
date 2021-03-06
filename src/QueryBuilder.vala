//	This file is part of FeedReader.
//
//	FeedReader is free software: you can redistribute it and/or modify
//	it under the terms of the GNU General Public License as published by
//	the Free Software Foundation, either version 3 of the License, or
//	(at your option) any later version.
//
//	FeedReader is distributed in the hope that it will be useful,
//	but WITHOUT ANY WARRANTY; without even the implied warranty of
//	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//	GNU General Public License for more details.
//
//	You should have received a copy of the GNU General Public License
//	along with FeedReader.  If not, see <http://www.gnu.org/licenses/>.

public class FeedReader.QueryBuilder : GLib.Object {

	private GLib.StringBuilder m_query;
	private QueryType m_type;
	private string m_table;
	private bool m_noError;
	private Gee.ArrayList<string> m_fields;
	private Gee.ArrayList<string> m_values;
	private Gee.ArrayList<string> m_conditions;
	private GLib.StringBuilder m_insert_fields;
	private GLib.StringBuilder m_insert_values;
	private string m_orderBy;
	private string m_limit;
	private string m_offset;

	public QueryBuilder(QueryType type, string table)
	{
		m_query = new GLib.StringBuilder();
		m_fields = new Gee.ArrayList<string>();
		m_values = new Gee.ArrayList<string>();
		m_conditions = new Gee.ArrayList<string>();
		m_type = type;
		m_table = table;
		m_noError = true;
		m_orderBy = "";
		m_limit = "";
		m_offset = "";
		m_insert_fields = new GLib.StringBuilder();
		m_insert_values = new GLib.StringBuilder();
	}

	public bool insertValuePair(string field, string value)
	{
		switch(m_type)
		{
			case QueryType.INSERT:
			case QueryType.INSERT_OR_IGNORE:
			case QueryType.INSERT_OR_REPLACE:
				m_fields.add(field);
				m_values.add(value);
				return true;
		}
		Logger.error("insertValuePair");
		return false;
	}

	public bool selectField(string field)
	{
		if(m_type == QueryType.SELECT)
		{
			m_fields.add(field);
			return true;
		}
		Logger.error("selectField");
		return false;
	}

	public bool updateValuePair(string field, string value, bool isString = false)
	{
		if(m_type == QueryType.UPDATE)
		{
			m_fields.add(field);
			if(isString)
				m_values.add("'%s'".printf(value));
			else
				m_values.add(value);
			return true;
		}
		Logger.error("updateValuePair");

		return false;
	}

	public bool addEqualsCondition(string field, string value, bool positive = true, bool isString = false)
	{
		if(m_type == QueryType.UPDATE
		|| m_type == QueryType.SELECT
		|| m_type == QueryType.DELETE)
		{
			string condition = "%s = %s";

			if(isString)
				condition = "%s = \"%s\"";

			if(!positive)
				condition = "NOT " + condition;

			m_conditions.add(condition.printf(field, value));
			return true;
		}
		Logger.error("addEqualsConditionString");
		return false;
	}

	public bool addCustomCondition(string condition)
	{
		if(m_type == QueryType.UPDATE
		|| m_type == QueryType.SELECT
		|| m_type == QueryType.DELETE)
		{
			m_conditions.add(condition);
			return true;
		}
		Logger.error("addCustomCondition");
		return false;
	}

	public bool addRangeConditionString(string field, Gee.List<string> values, bool instr = false)
	{
		if(!instr)
		{
			if(m_type == QueryType.UPDATE
			|| m_type == QueryType.SELECT
			|| m_type == QueryType.DELETE)
			{
				var compound_values = new GLib.StringBuilder();
				foreach(string value in values)
				{
					compound_values.append("\"");
					compound_values.append(value);
					compound_values.append("\",");
				}
				compound_values.erase(compound_values.len-1);
				m_conditions.add("%s IN (%s)".printf(field, compound_values.str));
				return true;
			}
		}
		else
		{
			if(m_type == QueryType.UPDATE
			|| m_type == QueryType.SELECT
			|| m_type == QueryType.DELETE)
			{
				foreach(string value in values)
				{
					this.addCustomCondition("instr(field, \"%s\") > 0".printf(value));
				}
			}
			return true;
		}

		Logger.error("addRangeConditionString");
		return false;
	}

	public bool addRangeConditionInt(string field, Gee.ArrayList<int> values)
	{
		if(m_type == QueryType.UPDATE
		|| m_type == QueryType.SELECT
		|| m_type == QueryType.DELETE)
		{
			var compound_values = new GLib.StringBuilder();
			foreach(int value in values)
			{
				compound_values.append(value.to_string());
				compound_values.append(",");
			}
			compound_values.erase(compound_values.len-1);
			m_conditions.add("%s IN (%s)".printf(field, compound_values.str));
			return true;
		}
		Logger.error("addRangeConditionInt");
		return false;
	}

	public bool orderBy(string field, bool desc)
	{
		if(m_type == QueryType.SELECT)
		{
			m_orderBy = " ORDER BY ";
			m_orderBy += field;
			m_orderBy += " COLLATE NOCASE";

			if(desc)
				m_orderBy += " DESC";
			else
				m_orderBy += " ASC";

			return true;
		}
		Logger.error("orderBy");
		return false;
	}

	public bool limit(uint limit)
	{
		if(m_type == QueryType.SELECT)
		{
			m_limit = " LIMIT %u".printf(limit);
			return true;
		}
		Logger.error("limit");
		return false;
	}

	public bool offset(uint offset)
	{
		if(m_type == QueryType.SELECT)
		{
			m_offset = " OFFSET %u".printf(offset);
			return true;
		}
		Logger.error("offset");
		return false;
	}

	public string build()
	{
		if(!m_noError)
		{
			Logger.error("build query");
			return "error setting up the query";
		}

		switch(m_type)
		{
			case QueryType.INSERT:
			case QueryType.INSERT_OR_IGNORE:
			case QueryType.INSERT_OR_REPLACE:
				m_query.append("INSERT ");

				if(m_type == QueryType.INSERT_OR_IGNORE)
					m_query.append("OR IGNORE ");
				else if(m_type == QueryType.INSERT_OR_REPLACE)
					m_query.append("OR REPLACE ");

				m_query.append("INTO ");
				m_query.append(m_table);
				m_query.append(" ");

				foreach(string field in m_fields)
				{
					m_insert_fields.append(",");
					m_insert_fields.append(field);
				}
				m_insert_fields.overwrite(0, "(").append(")");
				m_query.append(m_insert_fields.str);

				m_query.append(" VALUES ");

				foreach(string value in m_values)
				{
					m_insert_values.append(",");
					m_insert_values.append(value);
				}
				m_insert_values.overwrite(0, "(").append(")");
				m_query.append(m_insert_values.str);
				break;


			case QueryType.UPDATE:
				m_query.append("UPDATE ");
				m_query.append(m_table);
				m_query.append(" SET ");

				for(int i = 0; i < m_fields.size; i++)
				{
					m_query.append(m_fields.get(i));
					m_query.append(" = ");
					m_query.append(m_values.get(i));
					m_query.append(", ");
				}

				m_query.erase(m_query.len-2);
				m_query.append(buildConditions());
				break;


			case QueryType.DELETE:
				m_query.append("DELETE FROM ");
				m_query.append(m_table);
				m_query.append(buildConditions());
				break;


			case QueryType.SELECT:
				m_query.append("SELECT ");
				foreach(string field in m_fields)
				{
					m_query.append(field);
					m_query.append(", ");
				}
				m_query.erase(m_query.len-2);
				m_query.append(" FROM ");
				m_query.append(m_table);
				m_query.append(buildConditions());
				m_query.append(m_orderBy);
				m_query.append(m_limit);
				m_query.append(m_offset);
				break;
		}

		//print();
		return m_query.str;
	}

	private string buildConditions()
	{
		if(m_conditions.size == 0)
			return "";

		var conditions = new GLib.StringBuilder();
		conditions.append(" WHERE ");

		foreach(string condition in m_conditions)
		{
			conditions.append(condition);
			conditions.append(" AND ");
		}
		conditions.erase(conditions.len-4);
		return conditions.str;
	}

	public new string get()
	{
		return m_query.str;
	}

	public void reset()
	{
		m_query.str = "";
	}

	public void print()
	{
		Logger.debug(m_query.str);
	}
}
