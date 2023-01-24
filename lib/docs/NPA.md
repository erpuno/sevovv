Нормативно-правові акти СЕВ ОВВ 2.0
===================================

Протокол нормативно-правових актів передбачає роботу з додатковим ендпойнтом
для генерації ідентифікаторів НПА:

* НПА -- https://sev20.dir.gov.ua/csp/dirbus/bus.esb.LegalActService.cls
* СЕВ -- https://sev20.dir.gov.ua/csp/dirbus/bus.esb.IntegrationService.cls

НПА API
-------

### 1. Перевірка НПА скриньки

```
> NPA.today "1"
> NPA.yester "3"
> NPA.recent "0"
> NPA.list
> NPA.all
```

### 2. Створення НПА проекту

Для стадії 1:

```
> npaDoc = ERP.sevDoc(name: "3-фазний НПА", actType: "У", stage: "1")
> NPA.createDoc(@from, @to, npaDoc)
```

Для стадії 0 з використанням підлеглої та батьківської організацій:

```
> npaDoc = ERP.sevDoc(name: "4-фазний НПА", actType: "У", stage: "0")
> NPA.createDoc(@from, @to, npaDoc)
```

### 3. Закриття стадії

```
> NPA.close npaDoc, stage
```

### 4. Подовження проекту

```
> NPA.extend npaDoc, stage, prolongation_date
```

### 5. Пропуск стадії

```
> NPA.skip npaDoc, stage
```

СЕВ API
-------

Спеціальні шаблони інформаційних повідомлень СЕВ які використовуються для НПА протоколу:

### 1. Створення докумету НПА погодження

```
> SEV.LEGAL.testLegalRequest(request, urn, act, stage)
```

### 2. Створення докумету НПА підтвердження

```
> SEV.LEGAL.testLegalApproval(approve, request, urn, act, stage)
```

### 3. Створення інформаційного повідомлення для передачі НПА батьківській організації

```
> SEV.LEGAL.testLegalInformationTransfer(request, urn, act, stage)
```

ДП "ІНФОТЕХ"<br>
Максим Сохацький
