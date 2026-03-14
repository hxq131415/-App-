const canvas = document.getElementById('photoCanvas');
const ctx = canvas.getContext('2d');
const fileInput = document.getElementById('fileInput');
const sizeGroup = document.getElementById('sizeGroup');
const bgGroup = document.getElementById('bgGroup');
const zoomRange = document.getElementById('zoomRange');
const zoomValue = document.getElementById('zoomValue');
const downloadBtn = document.getElementById('downloadBtn');

const sizePresets = [
  { name: '一寸 295×413', width: 295, height: 413 },
  { name: '二寸 413×579', width: 413, height: 579 },
  { name: '小二寸 413×531', width: 413, height: 531 },
  { name: '护照 354×472', width: 354, height: 472 },
];

const bgPresets = [
  { name: '蓝底', color: '#4f9df8' },
  { name: '白底', color: '#ffffff' },
  { name: '红底', color: '#ec5a58' },
  { name: '灰底', color: '#d3d8e4' },
  { name: '渐变蓝', color: 'gradient' },
];

const state = {
  image: null,
  zoom: 1,
  currentSize: sizePresets[1],
  bgColor: bgPresets[0],
};

function init() {
  renderSizeOptions();
  renderBgOptions();
  bindEvents();
  drawPlaceholder();
}

function renderSizeOptions() {
  sizePresets.forEach((size, i) => {
    const chip = document.createElement('button');
    chip.className = `chip ${i === 1 ? 'active' : ''}`;
    chip.textContent = size.name;
    chip.type = 'button';
    chip.addEventListener('click', () => {
      [...sizeGroup.children].forEach((node) => node.classList.remove('active'));
      chip.classList.add('active');
      state.currentSize = size;
      canvas.width = size.width;
      canvas.height = size.height;
      redraw();
    });
    sizeGroup.appendChild(chip);
  });
}

function renderBgOptions() {
  bgPresets.forEach((bg, i) => {
    const swatch = document.createElement('button');
    swatch.className = `swatch ${i === 0 ? 'active' : ''}`;
    swatch.type = 'button';
    swatch.title = bg.name;
    swatch.style.background = bg.color === 'gradient'
      ? 'linear-gradient(135deg, #8ec5ff 0%, #4f9df8 55%, #256fdb 100%)'
      : bg.color;

    swatch.addEventListener('click', () => {
      [...bgGroup.children].forEach((node) => node.classList.remove('active'));
      swatch.classList.add('active');
      state.bgColor = bg;
      redraw();
    });

    bgGroup.appendChild(swatch);
  });
}

function bindEvents() {
  fileInput.addEventListener('change', (event) => {
    const file = event.target.files?.[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = () => {
      const img = new Image();
      img.onload = () => {
        state.image = img;
        state.zoom = 1;
        zoomRange.value = '100';
        zoomValue.textContent = '100%';
        downloadBtn.disabled = false;
        redraw();
      };
      img.src = reader.result;
    };
    reader.readAsDataURL(file);
  });

  zoomRange.addEventListener('input', () => {
    state.zoom = Number(zoomRange.value) / 100;
    zoomValue.textContent = `${zoomRange.value}%`;
    redraw();
  });

  downloadBtn.addEventListener('click', () => {
    const link = document.createElement('a');
    const name = `证件照-${state.currentSize.width}x${state.currentSize.height}.png`;
    link.download = name;
    link.href = canvas.toDataURL('image/png', 1);
    link.click();
  });
}

function drawBackground() {
  if (state.bgColor.color === 'gradient') {
    const gradient = ctx.createLinearGradient(0, 0, canvas.width, canvas.height);
    gradient.addColorStop(0, '#8ec5ff');
    gradient.addColorStop(0.5, '#4f9df8');
    gradient.addColorStop(1, '#256fdb');
    ctx.fillStyle = gradient;
  } else {
    ctx.fillStyle = state.bgColor.color;
  }

  ctx.fillRect(0, 0, canvas.width, canvas.height);
}

function redraw() {
  drawBackground();

  if (!state.image) {
    drawPlaceholder();
    return;
  }

  const { image, zoom } = state;
  const targetRatio = canvas.width / canvas.height;
  const imageRatio = image.width / image.height;

  let drawWidth;
  let drawHeight;

  if (imageRatio > targetRatio) {
    drawHeight = canvas.height * zoom;
    drawWidth = drawHeight * imageRatio;
  } else {
    drawWidth = canvas.width * zoom;
    drawHeight = drawWidth / imageRatio;
  }

  const x = (canvas.width - drawWidth) / 2;
  const y = (canvas.height - drawHeight) / 2;

  ctx.imageSmoothingEnabled = true;
  ctx.imageSmoothingQuality = 'high';
  ctx.drawImage(image, x, y, drawWidth, drawHeight);

  ctx.save();
  ctx.strokeStyle = 'rgba(255,255,255,0.75)';
  ctx.lineWidth = Math.max(2, canvas.width * 0.005);
  ctx.strokeRect(0, 0, canvas.width, canvas.height);
  ctx.restore();
}

function drawPlaceholder() {
  const cx = canvas.width / 2;
  const cy = canvas.height / 2;

  ctx.save();
  ctx.fillStyle = 'rgba(255,255,255,0.7)';
  ctx.beginPath();
  ctx.arc(cx, cy - canvas.height * 0.16, canvas.width * 0.1, 0, Math.PI * 2);
  ctx.fill();

  ctx.beginPath();
  ctx.roundRect(
    cx - canvas.width * 0.18,
    cy - canvas.height * 0.06,
    canvas.width * 0.36,
    canvas.height * 0.36,
    20,
  );
  ctx.fill();

  ctx.fillStyle = 'rgba(255,255,255,0.95)';
  ctx.font = `600 ${Math.max(18, canvas.width * 0.05)}px "Microsoft YaHei"`;
  ctx.textAlign = 'center';
  ctx.fillText('上传照片开始制作', cx, canvas.height * 0.86);
  ctx.restore();
}

init();
