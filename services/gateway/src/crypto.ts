import crypto from 'node:crypto'; import {config} from './config.js';
export const sha256=(value:string)=>crypto.createHash('sha256').update(value).digest('hex');
const key=()=>crypto.createHash('sha256').update(config.credentialsKey).digest();
export function encrypt(value:string){const iv=crypto.randomBytes(12),cipher=crypto.createCipheriv('aes-256-gcm',key(),iv),body=Buffer.concat([cipher.update(value,'utf8'),cipher.final()]),tag=cipher.getAuthTag();return Buffer.concat([iv,tag,body]).toString('base64');}
export function decrypt(value:string){const raw=Buffer.from(value,'base64'),iv=raw.subarray(0,12),tag=raw.subarray(12,28),body=raw.subarray(28),cipher=crypto.createDecipheriv('aes-256-gcm',key(),iv);cipher.setAuthTag(tag);return Buffer.concat([cipher.update(body),cipher.final()]).toString('utf8');}
export const newApiKey=()=>{const prefix=`urm_${crypto.randomBytes(4).toString('hex')}`,value=`${prefix}_${crypto.randomBytes(24).toString('base64url')}`;return {value,prefix,hash:sha256(value)};};
export const newInviteToken=()=>{const value=crypto.randomBytes(32).toString('base64url');return {value,hash:sha256(value)};};
