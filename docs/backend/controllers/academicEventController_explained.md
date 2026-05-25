# 📄 `controllers/academicEventController.js` — Complete Explanation

**File Path:** `backend/controllers/academicEventController.js`
**Lines:** 111

---

## 1. File Purpose
CRUD for academic calendar events (exams, holidays, deadlines). Features dynamic query building for month/year/type filtering, and `COALESCE`-based partial updates.

---

## 2. `getAcademicEvents` — Dynamic Query Builder

```js
const getAcademicEvents = async (req, res) => {
  const { month, year, type } = req.query;

  let where = [];
  let values = [];
  let idx = 1;

  if (month && year) {
    where.push(`(
      (EXTRACT(MONTH FROM start_date) = $${idx} AND EXTRACT(YEAR FROM start_date) = $${idx + 1})
      OR (EXTRACT(MONTH FROM end_date) = $${idx} AND EXTRACT(YEAR FROM end_date) = $${idx + 1})
      OR (start_date <= make_date($${idx + 1}::int, $${idx}::int, 1) AND end_date >= make_date($${idx + 1}::int, $${idx}::int, 1))
    )`);
    values.push(parseInt(month), parseInt(year));
    idx += 2;
  } else if (year) {
    where.push(`EXTRACT(YEAR FROM start_date) = $${idx}`);
    values.push(parseInt(year));
    idx += 1;
  }

  if (type && type !== 'all') {
    where.push(`event_type = $${idx}`);
    values.push(type);
    idx += 1;
  }

  const whereClause = where.length ? `WHERE ${where.join(' AND ')}` : '';
  const { rows } = await pool.query(
    `SELECT ae.*, u.name as created_by_name FROM academic_events ae
     LEFT JOIN users u ON ae.created_by = u.id ${whereClause} ORDER BY start_date ASC`,
    values
  );
  res.json({ success: true, events: rows });
};
```

### Dynamic Query Building Pattern
- `where = []` — Collects SQL conditions as strings
- `values = []` — Collects parameter values in matching order
- `idx = 1` — Tracks the `$N` parameter number

**Why dynamic?** If month/year/type filters were always required, the query would be simple. But they're optional — the UI shows all events by default, or filtered by month for the calendar view.

### Month/Year Overlap Logic
```sql
OR (start_date <= make_date($year, $month, 1) AND end_date >= make_date($year, $month, 1))
```
This third condition catches multi-month events (e.g., "Summer Break: June 1 - July 31"). An event that SPANS across April would still appear when filtering for April even though it doesn't start or end in April.

**`make_date($year::int, $month::int, 1)`** — PostgreSQL function that creates a DATE from year/month/day integers. The `::int` cast is needed because `$N` parameters are sent as strings.

---

## 3. `COALESCE` in `updateAcademicEvent`
```sql
SET title = COALESCE($1, title)
```
If `$1` is `NULL`, `COALESCE` returns `title` (the existing value). This enables partial updates — you can update only the colour without sending the title.

---

## 4. Security Gap
```js
router.post('/', protect, createAcademicEvent);  // Missing authorize()
```
Any authenticated user (including students) can create academic events. This should have `authorize('admin', 'faculty')`.

---

## 5. Final Summary
`academicEventController.js` demonstrates dynamic parameterized query building — a safe alternative to string interpolation. The month-overlap SQL logic is mathematically correct for multi-day events. The missing authorization on creation is a known security gap to fix.
