// massa shop 화면 동작 — 상품 목록·상세·장바구니·주문 요청을 products.json 하나로 그린다
(function () {
  'use strict';
  const API = 'https://api.massaviet.com/rest/v1/shop_order';
  const ANON = 'eyJhbGciOiAiSFMyNTYiLCAidHlwIjogIkpXVCJ9.eyJyb2xlIjogImFub24iLCAiaXNzIjogInN1cGFiYXNlIiwgImlhdCI6IDE3ODc0NTg4OTMsICJleHAiOiAyMTAyODE4ODkzfQ.7taJaAzxPRIkd0PeC5qnuacficFnazkBN54ttblUv-o';
  const CART_KEY = 'massa_shop_cart';
  const LANG_KEY = 'massa_shop_lang';

  const T = {
    vi: { search: 'Tìm sản phẩm', all: 'Tất cả', bannerT: 'Dụng cụ massage cho chuyên viên & gia đình',
      bannerP: 'Dầu, tinh dầu, đá nóng, khăn, giường massage — giao tận nơi toàn Việt Nam.', cats: 'Danh mục',
      items: 'Sản phẩm', count: '{n} sản phẩm', soon: 'Sản phẩm đang được cập nhật. Vui lòng quay lại sau!',
      none: 'Không tìm thấy sản phẩm phù hợp.', out: 'Hết hàng', add: 'Thêm vào giỏ', buy: 'Mua ngay',
      added: 'Đã thêm vào giỏ hàng', notFound: 'Không tìm thấy sản phẩm.', home: 'Trang chủ', cart: 'Giỏ hàng',
      cartEmpty: 'Giỏ hàng của bạn đang trống.', goShop: 'Tiếp tục mua sắm', remove: 'Xóa', total: 'Tạm tính',
      order: 'Thông tin đặt hàng', name: 'Họ tên', phone: 'Số điện thoại', addr: 'Địa chỉ giao hàng',
      memo: 'Ghi chú (không bắt buộc)', send: 'Gửi yêu cầu đặt hàng',
      payNote: 'Thanh toán trực tuyến sẽ sớm có. Sau khi nhận yêu cầu, massa sẽ gọi điện xác nhận đơn hàng, phí giao hàng và cách thanh toán.',
      need: 'Vui lòng nhập họ tên, số điện thoại và địa chỉ.', sending: 'Đang gửi…',
      sent: 'Đã gửi yêu cầu! massa sẽ liên hệ với bạn sớm.', fail: 'Gửi thất bại. Vui lòng thử lại sau.',
      back: 'Về massaviet.com', min: 'Đặt tối thiểu {n} sản phẩm', cmp: 'Mua lẻ' },
    ko: { search: '상품 검색', all: '전체', bannerT: '테라피스트와 가정을 위한 마사지 용품',
      bannerP: '오일, 아로마, 핫스톤, 타월, 마사지 베드까지 — 베트남 전역 배송.', cats: '카테고리',
      items: '상품', count: '상품 {n}개', soon: '상품을 준비하고 있어요. 곧 만나요!',
      none: '찾는 상품이 없어요.', out: '품절', add: '장바구니 담기', buy: '바로 주문',
      added: '장바구니에 담았어요', notFound: '상품을 찾을 수 없어요.', home: '홈', cart: '장바구니',
      cartEmpty: '장바구니가 비어 있어요.', goShop: '쇼핑 계속하기', remove: '삭제', total: '합계',
      order: '주문 정보', name: '이름', phone: '전화번호', addr: '배송 주소',
      memo: '요청 사항 (선택)', send: '주문 요청 보내기',
      payNote: '온라인 결제는 곧 열려요. 주문 요청을 받으면 massa가 전화로 주문 내용, 배송비, 결제 방법을 확인해 드려요.',
      need: '이름, 전화번호, 주소를 입력해 주세요.', sending: '보내는 중…',
      sent: '주문 요청을 보냈어요! massa가 곧 연락드릴게요.', fail: '보내지 못했어요. 잠시 후 다시 시도해 주세요.',
      back: 'massaviet.com 으로', min: '{n}개부터 주문 가능', cmp: '낱개 구매 시' },
    en: { search: 'Search products', all: 'All', bannerT: 'Massage supplies for therapists & homes',
      bannerP: 'Oils, aromatherapy, hot stones, towels, massage tables — delivered across Vietnam.', cats: 'Categories',
      items: 'Products', count: '{n} products', soon: 'Products are on the way. Please check back soon!',
      none: 'No matching products.', out: 'Sold out', add: 'Add to cart', buy: 'Order now',
      added: 'Added to cart', notFound: 'Product not found.', home: 'Home', cart: 'Cart',
      cartEmpty: 'Your cart is empty.', goShop: 'Continue shopping', remove: 'Remove', total: 'Subtotal',
      order: 'Order details', name: 'Full name', phone: 'Phone number', addr: 'Delivery address',
      memo: 'Note (optional)', send: 'Send order request',
      payNote: 'Online payment is coming soon. After we receive your request, massa will call to confirm the order, delivery fee and payment.',
      need: 'Please enter your name, phone and address.', sending: 'Sending…',
      sent: 'Request sent! massa will contact you soon.', fail: 'Could not send. Please try again later.',
      back: 'Back to massaviet.com', min: 'Minimum order: {n}', cmp: 'Bought separately' }
  };

  let lang = 'vi';
  try { lang = localStorage.getItem(LANG_KEY) || 'vi'; } catch (e) {}
  if (!T[lang]) lang = 'vi';
  const t = (k, n) => T[lang][k].replace('{n}', n);
  const $ = (s) => document.querySelector(s);
  const esc = (s) => String(s == null ? '' : s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const vnd = (n) => Number(n || 0).toLocaleString('vi-VN') + '₫';
  const qs = new URLSearchParams(location.search);

  function getCart() { try { return JSON.parse(localStorage.getItem(CART_KEY)) || []; } catch (e) { return []; } }
  function setCart(c) { try { localStorage.setItem(CART_KEY, JSON.stringify(c)); } catch (e) {} renderCount(); }
  function addToCart(id, qty) {
    const c = getCart(); const it = c.find((x) => x.id === id);
    if (it) it.qty += qty; else c.push({ id, qty });
    setCart(c);
  }
  function renderCount() {
    const n = getCart().reduce((a, x) => a + x.qty, 0);
    const b = $('#cartCount'); if (b) b.textContent = n ? String(n) : '';
  }
  function toast(msg) {
    let el = $('.toast'); if (!el) { el = document.createElement('div'); el.className = 'toast'; document.body.appendChild(el); }
    el.textContent = msg; el.classList.add('on'); clearTimeout(el._t); el._t = setTimeout(() => el.classList.remove('on'), 1800);
  }
  // compare = 같은 샵 낱개 상품으로 똑같이 맞췄을 때의 합계 (근거 없는 '정가'는 쓰지 않는다)
  const priceHtml = (p) => p.sale && p.sale < p.price
    ? `${vnd(p.sale)}<s>${vnd(p.price)}</s>`
    : p.compare > p.price
      ? `<span class="was"><small>${esc(t('cmp'))}</small> <span class="x">${vnd(p.compare)}</span></span>${vnd(p.price)}<span class="off">-${Math.round((1 - p.price / p.compare) * 100)}%</span>`
      : vnd(p.price);
  const unit = (p) => (p.sale && p.sale < p.price ? p.sale : p.price);
  const img = (p) => (p.images && p.images[0]) || '';
  // 단품 이익이 작은 상품은 최소 주문 수량(minQty)을 둔다
  const minQ = (p) => p.minQty || 1;
  const minHtml = (p) => (minQ(p) > 1 ? `<div class="min">${esc(t('min', minQ(p)))}</div>` : '');
  const catName = (data, id) => { const c = data.categories.find((x) => x.id === id); return c ? c.name[lang] : ''; };

  function header() {
    $('#top').innerHTML = `<div class="wrap">
      <a class="logo" href="./" translate="no">massa<small>shop</small></a>
      <form class="search" action="./"><input name="q" placeholder="${esc(t('search'))}" value="${esc(qs.get('q') || '')}">
        <button aria-label="${esc(t('search'))}">🔍</button></form>
      <div class="langs" translate="no">${['vi', 'ko', 'en'].map((l) => `<button data-l="${l}" class="${l === lang ? 'on' : ''}">${l.toUpperCase()}</button>`).join('')}</div>
      <a class="cart-btn" href="cart.html" aria-label="${esc(t('cart'))}">🛒<b id="cartCount"></b></a></div>`;
    document.documentElement.lang = lang;
    document.querySelectorAll('[data-l]').forEach((b) => b.onclick = () => {
      try { localStorage.setItem(LANG_KEY, b.dataset.l); } catch (e) {} location.reload();
    });
    $('#foot').innerHTML = `<div class="wrap">© massa · <a href="/">${esc(t('back'))}</a></div>`;
    const m = $('.langs-m');
    if (m) m.setAttribute('translate', 'no');
    if (m) m.innerHTML = ['vi', 'ko', 'en'].map((l) => `<button data-l="${l}" class="${l === lang ? 'on' : ''}">${l.toUpperCase()}</button>`).join('');
    document.querySelectorAll('.langs-m [data-l]').forEach((b) => b.onclick = () => {
      try { localStorage.setItem(LANG_KEY, b.dataset.l); } catch (e) {} location.reload();
    });
    renderCount();
  }

  function card(p) {
    return `<a class="card" href="product.html?id=${encodeURIComponent(p.id)}">
      <div class="img" style="background-image:url('${esc(img(p))}')"></div>
      <div class="body"><div class="name">${esc(p.name)}</div>
      <div class="price">${priceHtml(p)}</div>${minHtml(p)}${p.stock === false ? `<div class="badge-out">${esc(t('out'))}</div>` : ''}</div></a>`;
  }

  function pageHome(data) {
    const cat = qs.get('cat') || ''; const q = (qs.get('q') || '').trim().toLowerCase();
    $('#bannerT').textContent = t('bannerT'); $('#bannerP').textContent = t('bannerP');
    $('#cats').innerHTML = [`<a class="cat ${cat ? '' : 'on'}" href="./"><span class="ic">🛍️</span>${esc(t('all'))}</a>`]
      .concat(data.categories.map((c) => `<a class="cat ${c.id === cat ? 'on' : ''}" href="./?cat=${c.id}"><span class="ic">${c.icon}</span>${esc(c.name[lang])}</a>`)).join('');
    let list = data.products;
    if (cat) list = list.filter((p) => p.cat === cat);
    if (q) list = list.filter((p) => (p.name + ' ' + (p.desc || '')).toLowerCase().includes(q));
    $('#listTitle').textContent = cat ? catName(data, cat) : (q ? `“${qs.get('q')}”` : t('items'));
    $('#listCount').textContent = t('count', list.length);
    $('#grid').innerHTML = list.length ? `<div class="grid">${list.map(card).join('')}</div>`
      : `<div class="empty"><span class="ic">📦</span>${esc(data.products.length ? t('none') : t('soon'))}</div>`;
  }

  function pageProduct(data) {
    const p = data.products.find((x) => x.id === qs.get('id'));
    if (!p) { $('#detail').innerHTML = `<div class="empty"><span class="ic">📦</span>${esc(t('notFound'))}</div>`; return; }
    document.title = p.name + ' — massa shop';
    const imgs = p.images && p.images.length ? p.images : [''];
    let qty = minQ(p);
    $('#detail').innerHTML = `<div class="crumbs"><a href="./">${esc(t('home'))}</a> › <a href="./?cat=${esc(p.cat)}">${esc(catName(data, p.cat))}</a></div>
      <div class="detail"><div class="gallery"><div class="main" id="mainImg" style="background-image:url('${esc(imgs[0])}')"></div>
        ${imgs.length > 1 ? `<div class="thumbs">${imgs.map((u, i) => `<button data-i="${i}" class="${i ? '' : 'on'}" style="background-image:url('${esc(u)}')"></button>`).join('')}</div>` : ''}</div>
      <div class="info"><h1>${esc(p.name)}</h1><div class="price">${priceHtml(p)}</div>${minHtml(p)}
        <div class="actions"><div class="qty"><button id="qm">−</button><span id="qv">${qty}</span><button id="qp">+</button></div></div>
        <div class="actions"><button class="btn btn-line" id="add" ${p.stock === false ? 'disabled' : ''}>${esc(t('add'))}</button>
          <button class="btn btn-main" id="buy" ${p.stock === false ? 'disabled' : ''}>${esc(p.stock === false ? t('out') : t('buy'))}</button></div>
        ${p.desc ? `<div class="desc">${esc(p.desc)}</div>` : ''}</div></div>`;
    document.querySelectorAll('.thumbs button').forEach((b) => b.onclick = () => {
      $('#mainImg').style.backgroundImage = `url('${imgs[b.dataset.i]}')`;
      document.querySelectorAll('.thumbs button').forEach((x) => x.classList.toggle('on', x === b));
    });
    $('#qm').onclick = () => { qty = Math.max(minQ(p), qty - 1); $('#qv').textContent = qty; };
    $('#qp').onclick = () => { qty = Math.min(99, qty + 1); $('#qv').textContent = qty; };
    $('#add').onclick = () => { addToCart(p.id, qty); toast(t('added')); };
    $('#buy').onclick = () => { addToCart(p.id, qty); location.href = 'cart.html'; };
  }

  function pageCart(data) {
    const draw = () => {
      // 목록에서 빠진 상품은 장바구니에서도 뺀다 — 없는 물건을 주문받지 않도록
      const c = getCart().filter((x) => data.products.some((p) => p.id === x.id && p.stock !== false));
      c.forEach((x) => { x.qty = Math.max(minQ(data.products.find((p) => p.id === x.id)), x.qty); });
      setCart(c);
      $('#cartTitle').textContent = t('cart');
      if (!c.length) {
        $('#cart').innerHTML = `<div class="empty"><span class="ic">🛒</span>${esc(t('cartEmpty'))}<br><br><a class="btn btn-main" href="./">${esc(t('goShop'))}</a></div>`;
        return;
      }
      const rows = c.map((x) => ({ x, p: data.products.find((p) => p.id === x.id) }));
      const total = rows.reduce((a, r) => a + unit(r.p) * r.x.qty, 0);
      $('#cart').innerHTML = `<div class="cart-layout"><div class="box">${rows.map((r) => `<div class="line">
          <a class="img" href="product.html?id=${encodeURIComponent(r.p.id)}" style="background-image:url('${esc(img(r.p))}')"></a>
          <div><div>${esc(r.p.name)}</div><div class="price">${vnd(unit(r.p))}</div>${minHtml(r.p)}
            <button class="rm" data-rm="${esc(r.p.id)}">${esc(t('remove'))}</button></div>
          <div class="qty"><button data-d="-1" data-id="${esc(r.p.id)}">−</button><span>${r.x.qty}</span><button data-d="1" data-id="${esc(r.p.id)}">+</button></div>
        </div>`).join('')}</div>
        <div class="box"><div class="sum"><span>${esc(t('total'))}</span><span>${vnd(total)}</span></div>
          <form class="form" id="orderForm"><strong>${esc(t('order'))}</strong>
            <label>${esc(t('name'))}</label><input name="name" maxlength="80" autocomplete="name">
            <label>${esc(t('phone'))}</label><input name="phone" maxlength="40" inputmode="tel" autocomplete="tel">
            <label>${esc(t('addr'))}</label><textarea name="address" rows="2" maxlength="300" autocomplete="street-address"></textarea>
            <label>${esc(t('memo'))}</label><textarea name="note" rows="2" maxlength="1000"></textarea>
            <button class="btn btn-main" id="send">${esc(t('send'))}</button>
            <div class="note">${esc(t('payNote'))}</div><div class="msg" id="msg"></div></form></div></div>`;
      document.querySelectorAll('[data-d]').forEach((b) => b.onclick = () => {
        const cc = getCart(); const it = cc.find((x) => x.id === b.dataset.id);
        const pp = data.products.find((p) => p.id === it.id);
        it.qty = Math.min(99, Math.max(minQ(pp), it.qty + Number(b.dataset.d))); setCart(cc); draw();
      });
      document.querySelectorAll('[data-rm]').forEach((b) => b.onclick = () => { setCart(getCart().filter((x) => x.id !== b.dataset.rm)); draw(); });
      $('#orderForm').onsubmit = async (e) => {
        e.preventDefault();
        const f = e.target; const v = (k) => f[k].value.trim(); const msg = $('#msg');
        if (!v('name') || !v('phone') || !v('address')) { msg.className = 'msg err'; msg.textContent = t('need'); return; }
        const btn = $('#send'); btn.disabled = true; btn.textContent = t('sending');
        const items = rows.map((r) => ({ id: r.p.id, name: r.p.name, price: unit(r.p), qty: r.x.qty }));
        try {
          const res = await fetch(API, { method: 'POST',
            headers: { apikey: ANON, Authorization: 'Bearer ' + ANON, 'Content-Type': 'application/json', Prefer: 'return=minimal' },
            body: JSON.stringify({ items, total_vnd: total, name: v('name'), phone: v('phone'), address: v('address'), note: v('note') || null, lang }) });
          if (!res.ok) throw new Error(String(res.status));
          setCart([]);
          $('#cart').innerHTML = `<div class="empty"><span class="ic">✅</span>${esc(t('sent'))}<br><br><a class="btn btn-main" href="./">${esc(t('goShop'))}</a></div>`;
        } catch (err) {
          btn.disabled = false; btn.textContent = t('send'); msg.className = 'msg err'; msg.textContent = t('fail');
        }
      };
    };
    draw();
  }

  header();
  // 상품을 바꾸면 바로 보이도록 매번 새로 받는다 (Caddy 가 10분 캐시를 건다)
  fetch('products.json?t=' + Date.now()).then((r) => r.json()).then((data) => {
    const page = document.body.dataset.page;
    if (page === 'home') pageHome(data);
    if (page === 'product') pageProduct(data);
    if (page === 'cart') pageCart(data);
  });
})();
