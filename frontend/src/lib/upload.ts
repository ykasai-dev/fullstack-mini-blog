import { getAccessToken } from "./auth";

// 画像を S3 に置いて、そのキー（imageKey）を返す
export async function uploadImage(file: File): Promise<string> {
  // 1. API に、アップロード用の署名付き URL とキーを求める（ログインが必要）
  const res = await fetch(`${process.env.NEXT_PUBLIC_API_URL}/uploads`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${getAccessToken()}`,
    },
    body: JSON.stringify({ contentType: file.type }),
  });
  if (!res.ok) {
    throw new Error(`アップロードの準備に失敗しました（${res.status}）`);
  }
  const { uploadUrl, key } = await res.json();

  // 2. その URL に、画像を直接 PUT する（API を経由しない）
  //    Content-Type は、URL を作ったときと同じ値にする（違うと 403）
  const put = await fetch(uploadUrl, {
    method: "PUT",
    headers: { "Content-Type": file.type },
    body: file,
  });
  if (!put.ok) {
    throw new Error(`画像のアップロードに失敗しました（${put.status}）`);
  }
  return key;
}
