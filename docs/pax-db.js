// Pax's shared store on Supabase, shaped like the document store the app used inside claude.ai:
// db.collection("weeks").onSnapshot(...), db.doc("staples/list").set(...), and so on.
// Every document is one row in public.docs (path, collection, data). The whole table is small,
// so the app loads it once, keeps it in memory, and Supabase Realtime keeps every phone in step.
(function () {
  const parentOf = path => path.split("/").slice(0, -1).join("/");
  const lastOf = path => path.split("/").pop();

  function createPaxDb(sb) {
    const cache = new Map();        // path -> data
    const listeners = new Set();    // functions re-run on any change
    let channel = null;

    const notify = () => listeners.forEach(fn => { try { fn(); } catch (e) { console.error(e); } });
    const put = (path, data) => { if (data === null) cache.delete(path); else cache.set(path, data); notify(); };

    async function loadAll() {
      const rows = [];
      for (let from = 0; ; from += 1000) {
        const { data, error } = await sb.from("docs").select("path,data").range(from, from + 999);
        if (error) throw error;
        rows.push(...data);
        if (data.length < 1000) break;
      }
      cache.clear();
      rows.forEach(r => cache.set(r.path, r.data));
      notify();
    }

    function subscribe() {
      if (channel) sb.removeChannel(channel);
      channel = sb.channel("pax-docs")
        .on("postgres_changes", { event: "*", schema: "public", table: "docs" }, payload => {
          if (payload.eventType === "DELETE") put(payload.old.path, null);
          else put(payload.new.path, payload.new.data);
        })
        .subscribe(status => { if (status === "CHANNEL_ERROR" || status === "TIMED_OUT") setTimeout(subscribe, 3000); });
    }

    function snapDoc(path) {
      const d = cache.get(path);
      return { id: lastOf(path), exists: d !== undefined, data: () => d };
    }
    function snapColl(path, filter) {
      const docs = [...cache.keys()].filter(k => parentOf(k) === path).sort()
        .map(snapDoc).filter(s => !filter || filter(s.data()));
      return { docs, size: docs.length, empty: !docs.length };
    }
    function watch(compute, next) {
      let last;
      const fn = () => { const snap = compute(); const sig = JSON.stringify(snap.docs ? snap.docs.map(d => [d.id, d.data()]) : [snap.exists, snap.data()]); if (sig !== last) { last = sig; next(snap); } };
      listeners.add(fn); fn();
      return () => listeners.delete(fn);
    }

    function docRef(path) {
      return {
        id: lastOf(path), path,
        get: async () => snapDoc(path),
        async set(data) {
          const prev = cache.get(path); put(path, data);
          const { error } = await sb.from("docs").upsert({ path, collection: parentOf(path), data });
          if (error) { put(path, prev === undefined ? null : prev); throw error; }
        },
        async update(patch) {
          const prev = cache.get(path);
          put(path, deepMerge(prev || {}, patch));
          const { data, error } = await sb.rpc("merge_doc", { p_path: path, p_patch: patch });
          if (error) { put(path, prev === undefined ? null : prev); throw error; }
          put(path, data);
        },
        async delete() {
          const prev = cache.get(path); put(path, null);
          const { error } = await sb.from("docs").delete().eq("path", path);
          if (error) { if (prev !== undefined) put(path, prev); throw error; }
        },
        onSnapshot: (next) => watch(() => snapDoc(path), next),
        collection: c => collRef(path + "/" + c),
      };
    }
    function collRef(path, filter) {
      return {
        path,
        doc: id => docRef(path + "/" + (id || crypto.randomUUID())),
        add: async data => { const r = docRef(path + "/" + crypto.randomUUID()); await r.set(data); return r; },
        where: (field, op, value) => collRef(path, d => op === "==" ? d && d[field] === value : true),
        onSnapshot: (next) => watch(() => snapColl(path, filter), next),
      };
    }
    function deepMerge(a, b) {
      if (!a || typeof a !== "object" || Array.isArray(a) || !b || typeof b !== "object" || Array.isArray(b)) return b;
      const out = { ...a };
      for (const k of Object.keys(b)) out[k] = deepMerge(a[k], b[k]);
      return out;
    }

    return {
      doc: docRef, collection: p => collRef(p),
      // Every cached document under a path prefix, e.g. all("weeks/").
      all: prefix => [...cache.entries()].filter(([k]) => k.startsWith(prefix)).map(([path, data]) => ({ path, data })),
      async start() { await loadAll(); subscribe(); },
      refresh: loadAll,
    };
  }
  window.createPaxDb = createPaxDb;
})();
