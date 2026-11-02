// Cognito（Managed Login）とのやり取りをまとめる
const COGNITO_DOMAIN = process.env.NEXT_PUBLIC_COGNITO_DOMAIN;
const CLIENT_ID = process.env.NEXT_PUBLIC_COGNITO_CLIENT_ID ?? "";
// Cognito のコールバック URL（4-1-6）と完全に一致させる
const REDIRECT_URI = `${process.env.NEXT_PUBLIC_APP_URL}/callback`;
const ACCESS_TOKEN_KEY = "access_token";
const AUTH_CHANGE_EVENT = "auth-change";

// バイト列を、URL に入れても安全な文字列（base64url）にする
function base64UrlEncode(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
}

// 推測できないランダムな文字列を作る
function createRandomString(): string {
  return base64UrlEncode(crypto.getRandomValues(new Uint8Array(32)));
}

// 文字列を SHA-256 のハッシュ値にする（元には戻せない）
async function sha256(text: string): Promise<string> {
  const hash = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(text),
  );
  return base64UrlEncode(new Uint8Array(hash));
}

// Cognito のログイン画面へ移動する
export async function login() {
  const codeVerifier = createRandomString();
  // state：ログイン画面から戻ってきたとき、自分が始めたログインかを確かめる値
  const state = createRandomString();
  sessionStorage.setItem("pkce_code_verifier", codeVerifier);
  sessionStorage.setItem("oauth_state", state);

  const url = new URL("/oauth2/authorize", COGNITO_DOMAIN);
  url.search = new URLSearchParams({
    response_type: "code", // 認可コード付与
    client_id: CLIENT_ID,
    redirect_uri: REDIRECT_URI,
    scope: "openid email",
    state,
    code_challenge_method: "S256",
    code_challenge: await sha256(codeVerifier),
  }).toString();
  window.location.assign(url);
}

// /callback で呼ぶ：認可コード（code）をアクセストークンに交換する
export async function handleCallback(code: string, state: string) {
  if (state !== sessionStorage.getItem("oauth_state")) {
    throw new Error("state が一致しません");
  }

  const res = await fetch(new URL("/oauth2/token", COGNITO_DOMAIN), {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "authorization_code",
      client_id: CLIENT_ID,
      code,
      redirect_uri: REDIRECT_URI,
      // ログイン画面に送った code_challenge の元の文字列。Cognito が照らし合わせる
      code_verifier: sessionStorage.getItem("pkce_code_verifier") ?? "",
    }),
  });
  if (!res.ok) {
    throw new Error(`トークンの取得に失敗しました（${res.status}）`);
  }

  const tokens = await res.json();
  // タブを閉じると消える sessionStorage に保存する
  sessionStorage.setItem(ACCESS_TOKEN_KEY, tokens.access_token);
  sessionStorage.removeItem("pkce_code_verifier");
  sessionStorage.removeItem("oauth_state");
  window.dispatchEvent(new Event(AUTH_CHANGE_EVENT)); // AuthButton に知らせる
}

// 保存してあるアクセストークンを取り出す（なければ null）
export function getAccessToken(): string | null {
  return sessionStorage.getItem(ACCESS_TOKEN_KEY);
}

// ログイン状態が変わったら、callback を呼ぶ（AuthButton が使う）
export function subscribeAuth(callback: () => void) {
  window.addEventListener(AUTH_CHANGE_EVENT, callback);
  return () => window.removeEventListener(AUTH_CHANGE_EVENT, callback);
}

// アクセストークンを消し、Cognito 側のログイン状態も終わらせる
export function logout() {
  sessionStorage.removeItem(ACCESS_TOKEN_KEY);
  const url = new URL("/logout", COGNITO_DOMAIN);
  url.search = new URLSearchParams({
    client_id: CLIENT_ID,
    // Cognito のログアウト URL（4-1-6 の logout_urls）と完全に一致させる
    logout_uri: `${process.env.NEXT_PUBLIC_APP_URL}/`,
  }).toString();
  window.location.assign(url);
}
