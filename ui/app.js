function resourceName() {
    return window.GetParentResourceName ? GetParentResourceName() : 'd87-boosting';
}

async function post(name, data) {
    const resp = await fetch(`https://${resourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data || {}),
    });
    return resp.json();
}

let loggedIn = false;
let contractsData = [];

function setMessage(el, text, ok) {
    el.textContent = text || '';
    el.classList.toggle('success', !!ok);
}

function showTab(tab) {
    document.querySelectorAll('.tab-btn').forEach((b) => b.classList.toggle('active', b.dataset.tab === tab));
    document.getElementById('view-auth').classList.add('hidden');
    document.getElementById('view-account').classList.add('hidden');
    document.getElementById('view-send').classList.add('hidden');
    document.getElementById('view-ranking').classList.add('hidden');
    document.getElementById('view-contracts').classList.add('hidden');

    if (tab === 'account') {
        if (loggedIn) {
            document.getElementById('view-account').classList.remove('hidden');
            refreshBalance();
        } else {
            document.getElementById('view-auth').classList.remove('hidden');
        }
    } else if (tab === 'send') {
        document.getElementById('view-send').classList.remove('hidden');
    } else if (tab === 'ranking') {
        document.getElementById('view-ranking').classList.remove('hidden');
        loadRanking();
    } else if (tab === 'contracts') {
        document.getElementById('view-contracts').classList.remove('hidden');
        renderContracts();
    }
}

async function refreshBalance() {
    const res = await post('walletGetBalance');
    if (res.ok) {
        document.getElementById('account-balance').textContent = res.balance;
    }
}

async function loadRanking() {
    const res = await post('walletLeaderboard');
    const list = document.getElementById('ranking-list');
    list.innerHTML = '';
    (res.rows || []).forEach((row) => {
        const li = document.createElement('li');
        li.innerHTML = `<span>${row.username}</span><span>${row.balance} cripto</span>`;
        list.appendChild(li);
    });
}

function renderContracts() {
    const list = document.getElementById('contracts-list');
    list.innerHTML = '';

    if (!contractsData.length) {
        list.innerHTML = '<div class="contracts-empty">No tienes contratos disponibles ahora mismo.</div>';
        return;
    }

    contractsData.forEach((c) => {
        const card = document.createElement('div');
        card.className = 'contract-card';
        const inProgress = c.status === 'in_progress';
        const tierColor = c.tierColor || '#d4af37';
        card.style.borderLeftColor = tierColor;

        card.innerHTML = `
            <div class="contract-top">
                <span class="contract-tier" style="background:${tierColor}">${c.tierLabel}</span>
                ${c.trackerRequired ? '<span class="contract-tracker">🛰 Rastreador</span>' : ''}
                ${inProgress ? '<span class="contract-status">En curso</span>' : ''}
            </div>
            <div class="contract-row"><span>Vehículo</span><span>${c.car}</span></div>
            <div class="contract-row"><span>Ganancia</span><span>${c.reward} cripto</span></div>
            ${inProgress ? '' : `
            <label class="contract-keep-toggle">
                <input type="checkbox" data-keep-toggle="${c.id}">
                <span>Quedarme con el vehículo (${c.keepCost} cripto)</span>
            </label>
            <div class="contract-actions">
                <button class="btn-accept" data-id="${c.id}">Aceptar</button>
                <button class="btn-delete" data-id="${c.id}">Eliminar</button>
            </div>
            <div class="contract-transfer">
                <input type="text" placeholder="ID del jugador" data-transfer-input="${c.id}">
                <button data-transfer-btn="${c.id}">Traspasar</button>
            </div>`}
        `;
        list.appendChild(card);
    });

    list.querySelectorAll('.btn-accept').forEach((btn) => {
        btn.addEventListener('click', () => {
            const id = btn.dataset.id;
            const keepToggle = list.querySelector(`[data-keep-toggle="${id}"]`);
            const keep = keepToggle ? keepToggle.checked : false;
            post('contractAccept', { id, keep });
        });
    });
    list.querySelectorAll('.btn-delete').forEach((btn) => {
        btn.addEventListener('click', () => post('contractDelete', { id: btn.dataset.id }));
    });
    list.querySelectorAll('[data-transfer-btn]').forEach((btn) => {
        btn.addEventListener('click', () => {
            const id = btn.dataset.transferBtn;
            const input = list.querySelector(`[data-transfer-input="${id}"]`);
            const target = input ? input.value.trim() : '';
            if (!target) return;
            post('contractTransfer', { id, target });
        });
    });
}

window.addEventListener('message', (event) => {
    const data = event.data;
    const card = document.getElementById('vehicle-card');

    if (data.action === 'showCard') {
        document.getElementById('v-name').innerText = data.vehicle;
        document.getElementById('v-plate').innerText = data.plate;
        document.getElementById('v-color').innerText = data.color;
        document.getElementById('v-reward-label').innerText = data.rewardLabel || 'Ganancia (entrega)';
        document.getElementById('v-reward').innerText = data.reward;
        card.classList.remove('hidden');
    } else if (data.action === 'hideCard') {
        card.classList.add('hidden');
    } else if (data.action === 'openTablet') {
        document.getElementById('wallet-overlay').classList.remove('hidden');
        showTab('account');
    } else if (data.action === 'closeTablet') {
        document.getElementById('wallet-overlay').classList.add('hidden');
    } else if (data.action === 'contractsUpdate') {
        contractsData = data.contracts || [];
        if (!document.getElementById('view-contracts').classList.contains('hidden')) {
            renderContracts();
        }
    }
});

document.addEventListener('keyup', (e) => {
    if (e.key === 'Escape') {
        document.getElementById('wallet-overlay').classList.add('hidden');
        post('walletClose');
    }
});

document.getElementById('wallet-close').addEventListener('click', () => {
    document.getElementById('wallet-overlay').classList.add('hidden');
    post('walletClose');
});

document.querySelectorAll('.tab-btn').forEach((btn) => {
    btn.addEventListener('click', () => showTab(btn.dataset.tab));
});

document.getElementById('btn-show-login').addEventListener('click', () => {
    document.getElementById('btn-show-login').classList.add('active');
    document.getElementById('btn-show-register').classList.remove('active');
    document.getElementById('form-login').classList.remove('hidden');
    document.getElementById('form-register').classList.add('hidden');
    setMessage(document.getElementById('auth-message'), '');
});

document.getElementById('btn-show-register').addEventListener('click', () => {
    document.getElementById('btn-show-register').classList.add('active');
    document.getElementById('btn-show-login').classList.remove('active');
    document.getElementById('form-register').classList.remove('hidden');
    document.getElementById('form-login').classList.add('hidden');
    setMessage(document.getElementById('auth-message'), '');
});

document.getElementById('btn-login').addEventListener('click', async () => {
    const username = document.getElementById('login-username').value.trim();
    const password = document.getElementById('login-password').value;
    const msgEl = document.getElementById('auth-message');
    const res = await post('walletLogin', { username, password });
    setMessage(msgEl, res.message, res.ok);
    if (res.ok) {
        loggedIn = true;
        document.getElementById('account-balance').textContent = res.balance;
        showTab('account');
    }
});

document.getElementById('btn-register').addEventListener('click', async () => {
    const username = document.getElementById('register-username').value.trim();
    const password = document.getElementById('register-password').value;
    const msgEl = document.getElementById('auth-message');
    const res = await post('walletRegister', { username, password });
    setMessage(msgEl, res.message, res.ok);
    if (res.ok) {
        loggedIn = true;
        document.getElementById('account-balance').textContent = res.balance;
        showTab('account');
    }
});

document.getElementById('btn-refresh-balance').addEventListener('click', refreshBalance);

document.getElementById('btn-logout').addEventListener('click', async () => {
    await post('walletLogout');
    loggedIn = false;
    showTab('account');
});

document.getElementById('btn-send').addEventListener('click', async () => {
    const username = document.getElementById('send-username').value.trim();
    const amount = document.getElementById('send-amount').value;
    const msgEl = document.getElementById('send-message');
    if (!loggedIn) {
        setMessage(msgEl, 'Debes iniciar sesión en la pestaña Cuenta.', false);
        return;
    }
    const res = await post('walletSend', { username, amount });
    setMessage(msgEl, res.message, res.ok);
});
