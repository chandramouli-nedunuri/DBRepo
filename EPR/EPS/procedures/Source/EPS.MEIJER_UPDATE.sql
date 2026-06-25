
  CREATE OR REPLACE EDITIONABLE PROCEDURE "EPS"."MEIJER_UPDATE" (p_start rowid, p_end rowid)
IS
 cursor c1 is select rowid rid from eps.PATIENT
 where rowid between p_start and p_end;
 type table_rowid IS TABLE OF rowid;
 lrow table_rowid;
begin
 open c1;
 LOOP
 FETCH c1 BULK COLLECT INTO lrow LIMIT 10000;
 FORALL indx IN 1..lrow.count


 update eps.patient p
     set CONTACT_PHONE = 'H', CONTACT_SMS = 'D', CONTACT_EMAIL = 'D'
   where chain_id = 128
     and p.DECEASED_DATE is null
     and p.DEACTIVATE_DATE is null
     and ( p.CONTACT_PHONE not in ('C','H','W') or p.CONTACT_PHONE is null )
     and ( p.CONTACT_SMS != 'S'  or p.CONTACT_SMS is null )
     and ( p.CONTACT_EMAIL not in ('O','W','H') or p.CONTACT_EMAIL is null )
     and p.NO_AUTOMATED_CALLS is null
     and exists (select NULL from eps.address d
                  where d.chain_id = p.chain_id
                   and d.id_patient = p.id
                   and d.home_phone is not null
               )
     and rowid = lrow(indx);

  commit;
 EXIT WHEN c1%NOTFOUND;
 END LOOP;
 close c1;
end;