"use client";

import { useRouter } from "next/navigation";
import { useEffect, useRef, useState } from "react";
import { handleCallback } from "@/lib/auth";

export default function CallbackPage() {
  const router = useRouter();
  const [error, setError] = useState("");
  // 開発中は useEffect が2回呼ばれることがある。認可コードは1回しか使えないので、2回目は何もしない
  const started = useRef(false);

  useEffect(() => {
    if (started.current) return;
    started.current = true;

    // /callback?code=…&state=… の code と state を取り出して、トークンに交換する
    const params = new URLSearchParams(window.location.search);
    handleCallback(params.get("code") ?? "", params.get("state") ?? "")
      .then(() => router.replace("/")) // 成功したら一覧へ（戻るボタンで /callback に戻らないように replace）
      .catch((err) => setError(String(err)));
  }, [router]);

  return (
    <main>
      {error ? <p className="error">{error}</p> : <p>ログイン処理中...</p>}
    </main>
  );
}
