import random
import string
from datetime import datetime
from typing import Optional, Tuple, Dict, Any
from models import FamilyPlan, FamilyMember
from database import db

def generate_invite_code(length: int = 6) -> str:
    chars = string.ascii_uppercase + string.digits
    while True:
        code = "".join(random.choices(chars, k=length))
        if code not in db.family_plans:
            return code

class FamilyPlanService:
    @staticmethod
    def purchase_premium_and_create_plan(owner_id: str, owner_name: str) -> FamilyPlan:
        """
        Kullanıcı önce 39.99 ₺ öder. Ödeme tamamlandıktan sonra kendisine
        özel 6 haneli davet kodu üretilir ve arkadaş davet alanı açılır.
        """
        invite_code = generate_invite_code()
        plan = FamilyPlan(
            plan_id=f"plan-{owner_id}-{int(datetime.now().timestamp())}",
            owner_id=owner_id,
            owner_name=owner_name,
            price_monthly=39.99,
            invite_code=invite_code,
            max_extra_members=3,
            members=[],
            is_active=True,
            created_at=datetime.now().strftime("%Y-%m-%d %H:%M")
        )
        db.family_plans[invite_code] = plan
        db.user_plans[owner_id] = invite_code
        db.users_premium[owner_id] = True
        return plan

    @staticmethod
    def join_family_plan(invite_code: str, user_id: str, user_name: str) -> Tuple[bool, str, Optional[FamilyPlan]]:
        """
        Arkadaşın davet kodunu girerek plana katılması.
        Kodu giren anında Premium yetkisine kavuşur.
        """
        code = invite_code.strip().upper()
        if code not in db.family_plans:
            return False, "Geçersiz veya bulunamayan davet kodu!", None

        plan = db.family_plans[code]
        if not plan.is_active:
            return False, "Bu aile planı iptal edilmiş veya aktif değil.", None

        if plan.owner_id == user_id:
            return False, "Zaten bu aile planının yöneticisisiniz.", plan

        # Zaten ekli mi?
        if any(m.user_id == user_id for m in plan.members):
            return True, "Zaten bu plana dahilsiniz.", plan

        # Sınır kontrolü (1 asıl + 3 ek kişi)
        if len(plan.members) >= plan.max_extra_members:
            return False, f"Bu aile planının kontenjanı dolmuştur! (En fazla {plan.max_extra_members} ek üye)", None

        new_member = FamilyMember(
            user_id=user_id,
            name=user_name,
            joined_at=datetime.now().strftime("%Y-%m-%d %H:%M")
        )
        plan.members.append(new_member)
        db.user_plans[user_id] = code
        db.users_premium[user_id] = True
        return True, f"Tebrikler! {plan.owner_name} tarafından paylaşılan Premium Aile Planına katıldınız. Tüm kilitler açıldı!", plan

    @staticmethod
    def cancel_subscription_cascade(owner_id: str) -> Tuple[bool, str, int]:
        """
        İptal Zinciri (Cascade Cancellation):
        Ana plan sahibi aboneliğini iptal ettiği anda, onun davet koduyla
        plana dahil olan tüm üyelerin (+3 kişi) Premium yetkisi derhal sona erer.
        """
        user_code = db.user_plans.get(owner_id)
        if not user_code or user_code not in db.family_plans:
            return False, "Aktif bir aile planı aboneliğiniz bulunamadı.", 0

        plan = db.family_plans[user_code]
        if plan.owner_id != owner_id:
            return False, "Yalnızca planı satın alan yönetici aboneliği iptal edebilir.", 0

        # Planı pasife al
        plan.is_active = False

        # Yöneticinin premiumunu düşür
        db.users_premium[owner_id] = False

        # Tüm davetli üyelerin premium yetkisini anında sonlandır (İptal Zinciri)
        affected_count = len(plan.members)
        for member in plan.members:
            db.users_premium[member.user_id] = False
            if member.user_id in db.user_plans:
                del db.user_plans[member.user_id]

        plan.members.clear()

        return True, f"Abonelik iptal edildi. Sizin ve davet ettiğiniz {affected_count} üyenin Premium hakları sonlandırıldı.", affected_count

    @staticmethod
    def is_user_premium(user_id: str) -> bool:
        """Kullanıcının o an aktif Premium olup olmadığını kontrol eder."""
        return db.users_premium.get(user_id, False)
