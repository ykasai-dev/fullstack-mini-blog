"use client";

import { useSyncExternalStore } from "react";
import { getAccessToken, login, logout, subscribeAuth } from "@/lib/auth";

export default function AuthButton() {
  // sessionStorage のトークンの有無を、ログイン状態として使う
  // 3つ目の引数は、サーバーで描画するときの値（サーバーには sessionStorage がないので false）
  const loggedIn = useSyncExternalStore(
    subscribeAuth,
    () => getAccessToken() !== null,
    () => false,
  );

  return loggedIn ? (
    <button onClick={logout}>ログアウト</button>
  ) : (
    <button onClick={login}>ログイン</button>
  );
}
