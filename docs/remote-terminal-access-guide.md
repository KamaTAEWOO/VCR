# 외부 네트워크에서 핸드폰으로 노트북 터미널 접속하기

> 와이파이(로컬 네트워크)가 아닌, 인터넷을 통해 어디서든 접속 가능한 방법들

## 개요

집 밖에서 LTE/5G 등으로 집에 있는 노트북 터미널에 접속하려면 **터널링** 또는 **VPN** 솔루션이 필요합니다. 이 문서에서는 개인 사용자에게 적합한 3가지 방법을 소개합니다.

---

## 방법 비교

| 방법 | 난이도 | 비용 | 속도 | 보안 | 추천 용도 |
|------|--------|------|------|------|-----------|
| **Tailscale** | ⭐ 쉬움 | 무료 | 빠름 | 높음 | 개인용 최고 추천 |
| **Cloudflare Tunnel** | ⭐⭐ 보통 | 무료 | 빠름 | 높음 | 도메인 있을 때 |
| **ngrok** | ⭐ 쉬움 | 무료/유료 | 보통 | 보통 | 빠른 테스트용 |

---

## 방법 1: Tailscale (가장 추천)

### 왜 Tailscale인가?
- **WireGuard 기반** 최신 VPN 프로토콜
- **설치 5분 이내** 완료
- **무료** (개인용 100대 기기까지)
- 모바일 앱 지원 (iOS, Android)
- NAT 뒤에서도 작동 (포트포워딩 불필요)

### 설정 방법

#### Step 1: 노트북에 Tailscale 설치

**macOS:**
```bash
# Homebrew로 설치
brew install tailscale

# 또는 공식 앱 다운로드
# https://tailscale.com/download/mac
```

**Linux:**
```bash
curl -fsSL https://tailscale.com/install.sh | sh
```

**Windows:**
- https://tailscale.com/download/windows 에서 다운로드

#### Step 2: Tailscale 로그인 및 활성화

```bash
# macOS/Linux
sudo tailscale up

# 브라우저에서 로그인 (Google, GitHub, Microsoft 계정 사용 가능)
```

#### Step 3: 노트북에 SSH 서버 활성화

**macOS:**
```bash
# 시스템 설정 > 일반 > 공유 > 원격 로그인 활성화
# 또는 터미널에서:
sudo systemsetup -setremotelogin on
```

**Linux:**
```bash
sudo apt install openssh-server
sudo systemctl enable ssh
sudo systemctl start ssh
```

#### Step 4: 핸드폰에 Tailscale 설치

1. **iOS**: App Store에서 "Tailscale" 검색 후 설치
2. **Android**: Play Store에서 "Tailscale" 검색 후 설치
3. 같은 계정으로 로그인

#### Step 5: 핸드폰에서 SSH 클라이언트로 접속

**Android (Termux 사용):**
```bash
# Termux 설치 후
pkg update && pkg install openssh

# Tailscale IP로 접속 (100.x.x.x 형태)
ssh your-username@100.x.x.x
```

**iOS (Termius 또는 Blink Shell 사용):**
- Termius 앱 설치 (무료)
- 새 호스트 추가: Tailscale IP 입력
- 접속

#### Tailscale IP 확인 방법
```bash
# 노트북에서 실행
tailscale ip -4
# 출력 예: 100.64.0.1
```

---

## 방법 2: Cloudflare Tunnel

### 장점
- 완전 무료
- 도메인 기반 접속 (예: `ssh.mydomain.com`)
- Cloudflare 보안 기능 활용

### 단점
- Cloudflare 계정 + 도메인 필요
- 설정이 Tailscale보다 복잡

### 설정 방법

#### Step 1: Cloudflare 계정 및 도메인 설정
1. https://dash.cloudflare.com 에서 계정 생성
2. 도메인 추가 (기존 도메인 또는 Cloudflare Registrar에서 구매)

#### Step 2: cloudflared 설치

**macOS:**
```bash
brew install cloudflared
```

**Linux:**
```bash
curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o cloudflared
chmod +x cloudflared
sudo mv cloudflared /usr/local/bin/
```

#### Step 3: 터널 생성
```bash
# 로그인
cloudflared tunnel login

# 터널 생성
cloudflared tunnel create my-laptop

# 설정 파일 생성
cat > ~/.cloudflared/config.yml << EOF
tunnel: my-laptop
credentials-file: /Users/your-username/.cloudflared/<tunnel-id>.json

ingress:
  - hostname: ssh.yourdomain.com
    service: ssh://localhost:22
  - service: http_status:404
EOF

# DNS 레코드 생성
cloudflared tunnel route dns my-laptop ssh.yourdomain.com

# 터널 실행
cloudflared tunnel run my-laptop
```

#### Step 4: 핸드폰에서 접속

핸드폰에도 cloudflared 필요 (또는 Cloudflare Access 설정):

**Termux (Android):**
```bash
pkg install cloudflared
cloudflared access ssh --hostname ssh.yourdomain.com
```

---

## 방법 3: ngrok

### 장점
- 가장 빠른 설정 (1분)
- 계정 없이도 기본 사용 가능

### 단점
- 무료 버전은 URL이 매번 바뀜
- 무료 버전 속도 제한

### 설정 방법

#### Step 1: ngrok 설치

**macOS:**
```bash
brew install ngrok
```

**Linux:**
```bash
curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null
echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | sudo tee /etc/apt/sources.list.d/ngrok.list
sudo apt update && sudo apt install ngrok
```

#### Step 2: ngrok 계정 연결 (선택사항, 더 긴 세션용)
```bash
# https://ngrok.com 에서 가입 후 authtoken 확인
ngrok config add-authtoken YOUR_AUTH_TOKEN
```

#### Step 3: SSH 터널 시작
```bash
ngrok tcp 22
```

출력 예시:
```
Forwarding   tcp://0.tcp.ngrok.io:12345 -> localhost:22
```

#### Step 4: 핸드폰에서 접속

**Termux:**
```bash
ssh -p 12345 your-username@0.tcp.ngrok.io
```

---

## 핸드폰 SSH 클라이언트 추천

### Android
| 앱 | 가격 | 특징 |
|----|------|------|
| **Termux** | 무료 | 풀 리눅스 환경, 강력함 |
| **JuiceSSH** | 무료 | 사용 편리, UI 좋음 |
| **Termius** | 무료/유료 | 크로스플랫폼, 동기화 |

### iOS
| 앱 | 가격 | 특징 |
|----|------|------|
| **Termius** | 무료/유료 | 추천, UI 우수 |
| **Blink Shell** | 유료 ($20) | Mosh 지원, 전문가용 |
| **Prompt 3** | 유료 ($20) | Panic 제작, 고품질 |

---

## 보안 권장사항

### 1. SSH 키 인증 사용 (비밀번호 비활성화)

```bash
# 노트북에서 키 생성
ssh-keygen -t ed25519 -C "mobile-access"

# 공개키를 authorized_keys에 추가
cat ~/.ssh/id_ed25519.pub >> ~/.ssh/authorized_keys

# 비밀번호 인증 비활성화 (선택)
sudo nano /etc/ssh/sshd_config
# PasswordAuthentication no
```

### 2. fail2ban 설치 (Linux)
```bash
sudo apt install fail2ban
sudo systemctl enable fail2ban
```

### 3. 2FA 설정 (Tailscale)
Tailscale 관리 콘솔에서 2FA 활성화 권장

---

## 트러블슈팅

### "Connection refused" 에러
```bash
# SSH 서버 실행 확인
sudo systemctl status ssh  # Linux
sudo systemsetup -getremotelogin  # macOS
```

### Tailscale 연결 안 됨
```bash
# 상태 확인
tailscale status

# 재연결
sudo tailscale down
sudo tailscale up
```

### ngrok 세션 만료
- 무료 계정은 세션 시간 제한 있음
- 계정 가입 후 authtoken 설정하면 더 긴 세션 가능

---

## 최종 추천

**개인 사용자라면 Tailscale을 강력 추천합니다:**

1. 설정이 가장 간단함
2. 완전 무료 (개인용)
3. 가장 안전함 (WireGuard 암호화)
4. 모바일 앱 품질 우수
5. 포트포워딩 없이 NAT 통과

```bash
# 5분 안에 완료되는 요약
# 노트북: brew install tailscale && sudo tailscale up
# 핸드폰: Tailscale 앱 설치 → 로그인 → Termux에서 ssh user@100.x.x.x
```

---

## 참고 자료

- [Tailscale 공식 문서](https://tailscale.com/kb/)
- [Cloudflare Tunnel vs ngrok vs Tailscale 비교](https://dev.to/mechcloud_academy/cloudflare-tunnel-vs-ngrok-vs-tailscale-choosing-the-right-secure-tunneling-solution-4inm)
- [ngrok 대안 비교](https://tailscale.com/learn/ngrok-alternatives)
- [Termux SSH 설정 가이드](https://github.com/mrp-yt/termux_ssh)
- [2026 터널링 솔루션 가이드](https://dev.to/lightningdev123/top-10-ngrok-alternatives-in-2026-a-practical-guide-to-choosing-the-right-tunnel-54f6)
