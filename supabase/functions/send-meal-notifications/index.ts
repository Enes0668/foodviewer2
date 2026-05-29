import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// ─── Favori yemekler (Flutter'daki ile aynı) ────────────────────────────────
const KAHVALTI_FAVORILER = [
  'patates kızartması',
  'sade pişi',
  'karışık pizza',
  'menemen',
]

const AKSAM_FAVORILER = [
  'tavuk tantuni',
  'tavuk ızgara',
  'çökertme kebabı',
  'tavuk şiş',
  'tavuk külbastı',
  'çıtır tavuk',
  'tavuk şinitzel',
  'et tantuni',
  'burger',
  'tavuk burger',
  'fırında köri soslu tavuk',
  'tavuk çökertme',
  'fırında beşamel soslu tavuk',
]

// ─── Firebase ────────────────────────────────────────────────────────────────
const FIREBASE_PROJECT_ID = Deno.env.get('FIREBASE_PROJECT_ID')!
const SERVICE_ACCOUNT = JSON.parse(Deno.env.get('FIREBASE_SERVICE_ACCOUNT')!)

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const b64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\n/g, '')
  const binary = atob(b64)
  const buffer = new ArrayBuffer(binary.length)
  const view = new Uint8Array(buffer)
  for (let i = 0; i < binary.length; i++) view[i] = binary.charCodeAt(i)
  return buffer
}

function base64url(input: string): string {
  return btoa(input).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_')
}

async function getAccessToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000)
  const header = base64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }))
  const payload = base64url(
    JSON.stringify({
      iss: SERVICE_ACCOUNT.client_email,
      scope: 'https://www.googleapis.com/auth/firebase.messaging',
      aud: 'https://oauth2.googleapis.com/token',
      iat: now,
      exp: now + 3600,
    }),
  )
  const signingInput = `${header}.${payload}`
  const privateKey = await crypto.subtle.importKey(
    'pkcs8',
    pemToArrayBuffer(SERVICE_ACCOUNT.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  )
  const signatureBytes = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    privateKey,
    new TextEncoder().encode(signingInput),
  )
  const signature = btoa(String.fromCharCode(...new Uint8Array(signatureBytes)))
    .replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_')
  const jwt = `${signingInput}.${signature}`
  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  })
  const data = await res.json()
  return data.access_token
}

async function sendFCMNotification(
  token: string,
  title: string,
  body: string,
  accessToken: string,
): Promise<boolean> {
  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/messages:send`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        message: {
          token,
          notification: { title, body },
          android: { priority: 'high', notification: { sound: 'default' } },
        },
      }),
    },
  )
  const responseText = await res.text()
  console.log(`FCM response [${res.status}]:`, responseText)
  return res.ok
}

// ─── Favori kontrolü ─────────────────────────────────────────────────────────
function findFavorite(
  meal: Record<string, unknown>,
  fields: string[],
  favorites: string[],
): string | null {
  for (const field of fields) {
    const val = (meal[field] ?? '').toString().toLowerCase()
    for (const fav of favorites) {
      if (val.includes(fav.toLowerCase())) {
        return meal[field] as string
      }
    }
  }
  return null
}

// ─── Ana handler ─────────────────────────────────────────────────────────────
Deno.serve(async (req) => {
  try {
    const { type } = await req.json() // 'breakfast' veya 'dinner'
    const isBreakfast = type === 'breakfast'

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    )

    const column = isBreakfast ? 'breakfast_enabled' : 'dinner_enabled'

    // Bildirimi açık olan kullanıcıları al
    const { data: users, error } = await supabase
      .from('user_notification_settings')
      .select('fcm_token, city')
      .eq(column, true)
      .not('fcm_token', 'is', null)

    if (error) throw error
    if (!users || users.length === 0) {
      return new Response(JSON.stringify({ sent: 0 }), { status: 200 })
    }

    console.log(`Kullanıcı sayısı: ${users.length}, type: ${type}`)

    // Bugünün tarihini al (UTC+3 İstanbul)
    const now = new Date()
    now.setHours(now.getHours() + 3)
    const today = now.toISOString().split('T')[0]

    // Her şehir için menüyü bir kez çek (cache)
    const menuCache: Record<string, string | null> = {}

    async function getFavoriteForCity(city: string): Promise<string | null> {
      if (city in menuCache) return menuCache[city]

      if (isBreakfast) {
        const { data } = await supabase
          .from('kahvaltilar')
          .select('ana_kahvalti, diger1, diger2, diger3')
          .eq('kahvalti_tarihi', today)
          .eq('city', city)
          .limit(1)
          .single()

        menuCache[city] = data ? findFavorite(data, ['ana_kahvalti', 'diger1', 'diger2', 'diger3'], KAHVALTI_FAVORILER) : null
      } else {
        const { data } = await supabase
          .from('aksam_yemekleri')
          .select('yemek1, yemek2, pilav_makarna, ekstra')
          .eq('aksam_tarihi', today)
          .eq('city', city)
          .limit(1)
          .single()

        menuCache[city] = data ? findFavorite(data, ['yemek1', 'yemek2', 'pilav_makarna', 'ekstra'], AKSAM_FAVORILER) : null
      }

      return menuCache[city]
    }

    const accessToken = await getAccessToken()
    console.log('Access token alındı:', accessToken ? 'evet' : 'hayır')

    let sent = 0
    for (const user of users) {
      const city = user.city ?? 'Karaman'
      const favoriteMeal = await getFavoriteForCity(city)

      let title: string
      let body: string

      if (favoriteMeal) {
        title = isBreakfast ? '⭐ Bugün Favori Kahvaltın Var!' : '⭐ Bugün Favori Yemeğin Var!'
        body = `${favoriteMeal} bugün menüde!`
      } else {
        title = isBreakfast ? '🍳 Kahvaltı Zamanı!' : '🍽 Akşam Yemeği Zamanı!'
        body = isBreakfast ? 'Gün güzel bir kahvaltıyla başlar!' : 'Akşam yemeği seni bekliyor!'
      }

      const ok = await sendFCMNotification(user.fcm_token, title, body, accessToken)
      if (ok) sent++
    }

    return new Response(JSON.stringify({ sent, total: users.length }), { status: 200 })
  } catch (err) {
    console.error('Hata:', err)
    return new Response(JSON.stringify({ error: String(err) }), { status: 500 })
  }
})
